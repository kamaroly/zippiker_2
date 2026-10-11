defmodule ZippikerWeb.SalesLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Accounts, Catalog, Parties, Sales}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
    vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(18)}, opts)

    product =
      Catalog.create_product!(
        %{name: "Consulting", unit: "hour", unit_price: Decimal.new(100), tax_rate_id: vat.id},
        opts
      )

    %{customer: customer, vat: vat, product: product}
  end

  test "builds a quote with a product line and live totals", %{
    conn: conn,
    opts: opts,
    customer: customer,
    product: product
  } do
    {:ok, view, _html} = live(conn, ~p"/quotes/new?customer_id=#{customer.id}")

    view
    |> form("#document-form",
      document: %{lines: %{"0" => %{product_id: product.id, quantity: "2"}}}
    )
    |> render_change()

    # Product autofill: 2 × 100 + 18% tax
    assert render(view) =~ "$236"

    view |> form("#document-form") |> render_submit()
    {path, _flash} = assert_redirect(view)

    [quote] = Sales.list_quotes!(opts)
    assert path == "/quotes/#{quote.id}"
    assert Money.equal?(quote.total, Money.new!(:USD, 236))
  end

  test "quote → accept → invoice → issue → payment", %{
    conn: conn,
    opts: opts,
    customer: customer,
    vat: vat
  } do
    quote =
      Sales.create_quote!(
        %{
          customer_id: customer.id,
          lines: [%{description: "Work", quantity: "1", unit_price: "1000", tax_rate_id: vat.id}]
        },
        opts
      )

    {:ok, view, _html} = live(conn, ~p"/quotes/#{quote}")
    view |> element("#accept-quote") |> render_click()
    view |> element("#invoice-quote") |> render_click()
    {path, _} = assert_redirect(view)

    {:ok, view, _html} = live(conn, path)
    view |> element("#issue-invoice") |> render_click()
    assert has_element?(view, "#record-payment")

    [invoice] = Sales.list_invoices!(opts)
    {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}/payment")

    view
    |> form("#payment-form", payment: %{amount: "1180", method: "bank_transfer"})
    |> render_submit()

    assert Sales.get_invoice!(invoice.id, opts).status == :paid
    assert has_element?(view, "#payments li")
  end

  test "print page renders the document", %{conn: conn, opts: opts, customer: customer} do
    quote =
      Sales.create_quote!(
        %{customer_id: customer.id, lines: [%{description: "Work", unit_price: "10"}]},
        opts
      )

    {:ok, view, _html} = live(conn, ~p"/quotes/#{quote}/print")
    assert has_element?(view, "#document-paper")
    assert has_element?(view, "#print-button")
  end

  test "creates a product", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/products/new")

    view
    |> form("#product-form", product: %{name: "Training", unit: "day", unit_price: "800"})
    |> render_submit()

    assert Enum.any?(Catalog.list_products!(opts), &(&1.name == "Training"))
  end

  test "invites a teammate from workspace settings", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/settings/users")

    view
    |> form("#invite-form", invitation: %{email: "mate@example.com", role: "member"})
    |> render_submit()

    assert [%{email: email}] = Accounts.list_pending_invitations!(opts)
    assert to_string(email) == "mate@example.com"
    assert has_element?(view, "#invitations li", "mate@example.com")
  end

  test "adds an address to a company", %{conn: conn, opts: opts, customer: customer} do
    {:ok, view, _html} = live(conn, ~p"/companies/#{customer}")
    view |> element("#add-address") |> render_click()

    view
    |> form("#address-form", address: %{line1: "1 Main St", city: "Kigali", country: "rw"})
    |> render_submit()

    assert [%{country: "RW", city: "Kigali"}] = Parties.list_addresses!(customer.id, opts)
  end
end
