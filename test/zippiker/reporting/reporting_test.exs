defmodule Zippiker.ReportingTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Catalog, HR, Parties, Purchasing, Reporting, Sales}
  alias Zippiker.Reporting.Catalog, as: ReportCatalog

  setup do
    {user, organization} = workspace_fixture()
    opts = [actor: user, tenant: organization]

    customer =
      Parties.create_party!(
        %{kind: :organization, name: "Globex", phone: "+254700000001", tags: ["retail"]},
        opts
      )

    supplier =
      Parties.create_party!(
        %{kind: :organization, name: "Acme Supplies", roles: [:supplier]},
        opts
      )

    vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(16)}, opts)

    widget =
      Catalog.create_product!(
        %{
          name: "Widget",
          kind: :goods,
          track_inventory?: true,
          unit_price: Decimal.new(20),
          cost_price: Decimal.new(5)
        },
        opts
      )

    line = fn product, quantity, price ->
      %{
        product_id: product.id,
        description: product.name,
        quantity: quantity,
        unit_price: price,
        tax_rate_id: vat.id
      }
    end

    # Buy 10 widgets at 5, bill and pay part of it.
    po =
      %{supplier_id: supplier.id, lines: [line.(widget, "10", "5")]}
      |> Purchasing.create_purchase_order!(opts)
      |> Purchasing.place_purchase_order!(opts)
      |> Purchasing.receive_purchase_order!(%{}, opts)

    bill = po.id |> Purchasing.bill_purchase_order!(opts) |> Purchasing.approve_bill!(opts)

    Purchasing.record_bill_payment!(
      %{bill_id: bill.id, amount: Money.new!(:USD, 20), method: :cheque, reference: "CHQ-1"},
      opts
    )

    # A second order still open.
    %{supplier_id: supplier.id, lines: [line.(widget, "4", "5")]}
    |> Purchasing.create_purchase_order!(opts)
    |> Purchasing.place_purchase_order!(opts)

    # Sell 3 widgets (overdue invoice) and part-pay it.
    invoice =
      %{
        customer_id: customer.id,
        issued_on: Date.add(Date.utc_today(), -45),
        due_on: Date.add(Date.utc_today(), -15),
        lines: [line.(widget, "3", "20")]
      }
      |> Sales.create_invoice!(opts)
      |> Sales.issue_invoice!(opts)

    Sales.record_payment!(
      %{invoice_id: invoice.id, amount: Money.new!(:USD, 30), method: :bank_transfer},
      opts
    )

    # An open sales order for 2 more.
    %{customer_id: customer.id, lines: [line.(widget, "2", "20")]}
    |> Sales.create_sales_order!(opts)
    |> Sales.confirm_sales_order!(opts)

    employee = HR.hire_employee!(%{first_name: "Ada", user_id: user.id}, opts)

    HR.log_time!(
      %{
        date: Date.utc_today(),
        hours: "3",
        billable?: true,
        hourly_rate: "50",
        customer_id: customer.id,
        description: "Installation"
      },
      opts
    )

    HR.log_time!(%{date: Date.utc_today(), hours: "2", pay_type: :overtime}, opts)

    %{
      opts: opts,
      organization: organization,
      customer: customer,
      invoice: invoice,
      bill: bill,
      employee: employee
    }
  end

  defp run(key, args \\ %{}, opts), do: Reporting.run_report!(key, args, opts)

  defp row(report, label) do
    Enum.find(report.rows, &(hd(&1.cells) == label))
  end

  defp d(value), do: Decimal.new(value)

  test "every report runs and returns a well-formed table", %{opts: opts} do
    catalog = Reporting.report_catalog!(opts)
    assert length(catalog) == length(ReportCatalog.all())

    for %{key: key} <- catalog do
      report = run(key, opts)
      width = length(report.columns)
      assert report.title

      for row <- report.rows, row.kind != :heading do
        assert length(row.cells) == width, "#{key}: row #{inspect(row.cells)} has the wrong width"
      end
    end
  end

  test "reports are limited to the workspace's modules", %{opts: opts, organization: organization} do
    Accounts.set_plan_limits!(organization, %{enabled_modules: [:crm]}, authorize?: false)
    organization = Accounts.get_organization!(organization.id, authorize?: false)
    opts = Keyword.put(opts, :tenant, organization)

    keys = opts |> Reporting.report_catalog!() |> Enum.map(& &1.key)
    assert "customer-contact-list" in keys
    refute "profit-and-loss" in keys
    assert {:error, _} = Reporting.run_report("profit-and-loss", %{}, opts)
  end

  test "receivables: ageing, balances and collections", %{opts: opts} do
    # 3 × 20 + 16% VAT = 69.60, 30 paid.
    summary = run("ar-ageing-summary", opts)
    globex = row(summary, "Globex")
    assert Decimal.eq?(Enum.at(globex.cells, 1), d(0))
    assert Decimal.eq?(Enum.at(globex.cells, 2), d("39.60"))
    assert Decimal.eq?(List.last(globex.cells), d("39.60"))

    assert Decimal.eq?(
             List.last(row(run("customer-balance-summary", opts), "Globex").cells),
             d("39.60")
           )

    assert row(run("collections", opts), "Globex · +254700000001")
  end

  test "payables: ageing, cheques and unpaid bills", %{opts: opts} do
    # 10 × 5 + 16% = 58, 20 paid.
    globex = row(run("ap-ageing-summary", opts), "Acme Supplies")
    assert Decimal.eq?(List.last(globex.cells), d(38))

    [cheque] = Enum.filter(run("cheque-detail", opts).rows, &(&1.kind == :row))
    assert Enum.at(cheque.cells, 1) == "CHQ-1"
  end

  test "financial statements agree with each other", %{opts: opts} do
    pl = run("profit-and-loss", opts)
    net = List.last(row(pl, "Net income").cells)

    # Sales 60 less cost of 3 widgets at 5.
    assert Decimal.eq?(net, d(45))

    bs = run("balance-sheet", opts)
    assets = List.last(row(bs, "Total assets").cells)
    liabilities_and_equity = List.last(row(bs, "Total liabilities and equity").cells)
    assert Decimal.eq?(assets, liabilities_and_equity)

    cash = run("statement-of-cash-flows", opts)
    # Received 30, paid 20.
    assert Decimal.eq?(List.last(row(cash, "Net change in cash").cells), d(10))

    tb = run("trial-balance", opts)
    totals = row(tb, "Total")
    assert Decimal.eq?(Enum.at(totals.cells, 1), Enum.at(totals.cells, 2))

    assert Enum.filter(run("invalid-journal-transactions", opts).rows, &(&1.kind == :row)) == []
  end

  test "inventory status counts what's ordered and committed", %{opts: opts} do
    widget = row(run("inventory-status", opts), "Widget")
    # On hand 7 (10 in, 3 out), 4 on order, 2 committed.
    assert [_, _, on_hand, on_order, committed, available | _] = widget.cells
    assert Decimal.eq?(on_hand, d(7))
    assert Decimal.eq?(on_order, d(4))
    assert Decimal.eq?(committed, d(2))
    assert Decimal.eq?(available, d(5))
  end

  test "VAT summary nets output tax against input tax", %{opts: opts} do
    vat = row(run("vat-summary", opts), "VAT")
    # Output 16% of 60 = 9.60, input 16% of 50 = 8.
    assert Decimal.eq?(List.last(vat.cells), d("1.60"))
  end

  test "time reports split billable, unbilled and pay types", %{opts: opts} do
    unbilled = run("unbilled-time", opts)
    assert Decimal.eq?(List.last(row(unbilled, "Total").cells), d(150))

    by_pay_type = row(run("time-summary-by-pay-type", opts), "Total")
    assert Decimal.eq?(List.last(by_pay_type.cells), d(5))
  end

  test "the audit log lists document changes", %{opts: opts} do
    rows = Enum.filter(run("audit-log", opts).rows, &(&1.kind == :row))
    assert Enum.any?(rows, &(Enum.at(&1.cells, 3) == "Invoice"))
  end
end
