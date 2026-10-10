defmodule Zippiker.SalesTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Catalog, Crm, Parties, Sales}

  setup do
    {user, organization} = workspace_fixture()
    opts = [actor: user, tenant: organization]
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
    vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(18)}, opts)
    %{opts: opts, customer: customer, vat: vat, organization: organization}
  end

  defp lines(vat) do
    [
      %{description: "Consulting", quantity: "10", unit_price: "100", tax_rate_id: vat.id},
      %{description: "Setup", quantity: "1", unit_price: "500", discount_percent: "10"}
    ]
  end

  test "prices lines and totals a quote, numbering it per year", %{
    opts: opts,
    customer: customer,
    vat: vat
  } do
    quote = Sales.create_quote!(%{customer_id: customer.id, lines: lines(vat)}, opts)
    year = Date.utc_today().year

    assert quote.number == "QUO-#{year}-0001"
    # 10 × 100 = 1000 + 18% = 1180; 500 − 10% = 450 (no tax)
    assert Money.equal?(quote.subtotal, Money.new!(:USD, "1450"))
    assert Money.equal?(quote.tax_total, Money.new!(:USD, "180"))
    assert Money.equal?(quote.total, Money.new!(:USD, "1630"))

    second = Sales.create_quote!(%{customer_id: customer.id, lines: lines(vat)}, opts)
    assert second.number == "QUO-#{year}-0002"
  end

  test "editing lines recomputes totals", %{opts: opts, customer: customer, vat: vat} do
    quote = Sales.create_quote!(%{customer_id: customer.id, lines: lines(vat)}, opts)
    quote = Ash.load!(quote, :lines, opts)
    [first | _] = quote.lines

    quote =
      Sales.update_quote!(
        quote,
        %{
          lines: [
            %{
              id: first.id,
              description: "Consulting",
              quantity: "1",
              unit_price: "100",
              tax_rate_id: vat.id
            }
          ]
        },
        opts
      )

    assert Money.equal?(quote.total, Money.new!(:USD, "118"))
  end

  test "accepting a quote wins its deal", %{
    opts: opts,
    customer: customer,
    vat: vat,
    organization: organization
  } do
    deal =
      Crm.create_deal!(
        %{title: "Big", stage_id: stage(organization, "Proposal").id, company_id: customer.id},
        opts
      )

    quote =
      Sales.create_quote!(%{customer_id: customer.id, deal_id: deal.id, lines: lines(vat)}, opts)

    quote = Sales.accept_quote!(quote, opts)
    assert quote.status == :accepted
    assert Crm.get_deal!(deal.id, opts).status == :won
  end

  test "quote to invoice to paid", %{opts: opts, customer: customer, vat: vat} do
    quote =
      Sales.create_quote!(%{customer_id: customer.id, lines: lines(vat)}, opts)
      |> Sales.accept_quote!(opts)

    invoice = Sales.invoice_quote!(quote.id, opts)
    assert invoice.status == :draft
    assert is_nil(invoice.number)
    assert Money.equal?(invoice.total, Money.new!(:USD, "1630"))
    assert {:error, _} = Sales.invoice_quote(quote.id, opts)

    invoice = Sales.issue_invoice!(invoice, opts)
    assert invoice.number == "INV-#{Date.utc_today().year}-0001"
    assert invoice.due_on == Date.add(Date.utc_today(), 30)

    assert {:error, _} =
             Sales.record_payment(%{invoice_id: invoice.id, amount: Money.new!(:USD, 5000)}, opts)

    Sales.record_payment!(%{invoice_id: invoice.id, amount: Money.new!(:USD, 630)}, opts)
    invoice = Sales.get_invoice!(invoice.id, opts ++ [load: [:amount_due]])
    assert invoice.status == :issued
    assert Money.equal?(invoice.amount_due, Money.new!(:USD, 1000))

    Sales.record_payment!(%{invoice_id: invoice.id, amount: Money.new!(:USD, 1000)}, opts)
    invoice = Sales.get_invoice!(invoice.id, opts)
    assert invoice.status == :paid
    assert {:error, _} = Sales.void_invoice(invoice, opts)
  end

  test "can't issue an empty invoice or edit an issued one", %{
    opts: opts,
    customer: customer,
    vat: vat
  } do
    assert {:error, _} =
             customer.id
             |> then(&Sales.create_invoice!(%{customer_id: &1}, opts))
             |> Sales.issue_invoice(opts)

    invoice =
      Sales.create_invoice!(%{customer_id: customer.id, lines: lines(vat)}, opts)
      |> Sales.issue_invoice!(opts)

    assert {:error, _} = Sales.update_invoice(invoice, %{notes: "changed"}, opts)
  end

  test "sales summary", %{opts: opts, customer: customer, vat: vat} do
    invoice =
      Sales.create_invoice!(%{customer_id: customer.id, lines: lines(vat)}, opts)
      |> Sales.issue_invoice!(opts)

    Sales.record_payment!(%{invoice_id: invoice.id, amount: Money.new!(:USD, 30)}, opts)

    summary = Sales.sales_summary!(opts)
    assert Money.equal?(summary.receivable, Money.new!(:USD, 1600))
    assert Money.equal?(summary.invoiced_this_month, Money.new!(:USD, 1630))
    assert Money.equal?(summary.collected_this_month, Money.new!(:USD, 30))
    assert summary.open_count == 1
  end
end
