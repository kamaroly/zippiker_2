defmodule ZippikerWeb.DocumentsLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Catalog, HR, Parties, Purchasing, Sales}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    party = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)

    widget =
      Catalog.create_product!(
        %{name: "Widget", kind: :goods, unit_price: Decimal.new(20), cost_price: Decimal.new(5)},
        opts
      )

    %{party: party, widget: widget}
  end

  defp line(widget, price),
    do: %{product_id: widget.id, description: "Widget", quantity: "3", unit_price: price}

  test "the party page offers every transaction and lists them", %{
    conn: conn,
    opts: opts,
    party: party,
    widget: widget
  } do
    Sales.create_quote!(%{customer_id: party.id, lines: [line(widget, "20")]}, opts)
    Purchasing.create_rfq!(%{supplier_id: party.id, lines: [line(widget, "5")]}, opts)

    {:ok, view, _html} = live(conn, ~p"/companies/#{party}")

    for path <- [
          "/quotes/new?customer_id=#{party.id}",
          "/orders/new?customer_id=#{party.id}",
          "/invoices/new?customer_id=#{party.id}",
          "/rfqs/new?supplier_id=#{party.id}",
          "/purchase-orders/new?supplier_id=#{party.id}",
          "/bills/new?supplier_id=#{party.id}"
        ] do
      assert has_element?(view, ~s|#party-transactions a[href="#{path}"]|)
      assert {:ok, _form, _html} = live(conn, path)
    end

    assert has_element?(view, "#party-sales", "QUO-")
    assert has_element?(view, "#party-purchases", "RFQ-")
  end

  test "request for quotation → purchase order", %{
    conn: conn,
    opts: opts,
    party: party,
    widget: widget
  } do
    rfq = Purchasing.create_rfq!(%{supplier_id: party.id, lines: [line(widget, "5")]}, opts)
    assert rfq.number =~ ~r/^RFQ-/

    {:ok, view, _html} = live(conn, ~p"/rfqs/#{rfq}")
    view |> element("#send-rfq") |> render_click()
    view |> element("#quoted-rfq") |> render_click()
    view |> element("#order-rfq") |> render_click()
    {path, _flash} = assert_redirect(view)

    [order] = Purchasing.list_purchase_orders!(opts)
    assert path == "/purchase-orders/#{order.id}"
    assert order.rfq_id == rfq.id
    assert Purchasing.get_rfq!(rfq.id, opts).status == :accepted
    assert {:ok, _view, _html} = live(conn, ~p"/rfqs/#{rfq}/print")
    assert {:ok, _view, _html} = live(conn, ~p"/rfqs")
  end

  test "a draft quote becomes an order (and is accepted)", %{
    conn: conn,
    opts: opts,
    party: party,
    widget: widget
  } do
    quote = Sales.create_quote!(%{customer_id: party.id, lines: [line(widget, "20")]}, opts)
    {:ok, view, _html} = live(conn, ~p"/quotes/#{quote}")
    view |> element("#order-quote") |> render_click()
    {path, _flash} = assert_redirect(view)

    assert path =~ "/orders/"
    assert Sales.get_quote!(quote.id, opts).status == :accepted
  end

  test "every document type can be duplicated", %{
    conn: conn,
    opts: opts,
    party: party,
    widget: widget
  } do
    quote = Sales.create_quote!(%{customer_id: party.id, lines: [line(widget, "20")]}, opts)
    order = Sales.create_sales_order!(%{customer_id: party.id, lines: [line(widget, "20")]}, opts)
    invoice = Sales.create_invoice!(%{customer_id: party.id, lines: [line(widget, "20")]}, opts)
    rfq = Purchasing.create_rfq!(%{supplier_id: party.id, lines: [line(widget, "5")]}, opts)

    po =
      Purchasing.create_purchase_order!(
        %{supplier_id: party.id, lines: [line(widget, "5")]},
        opts
      )

    bill = Purchasing.create_bill!(%{supplier_id: party.id, lines: [line(widget, "5")]}, opts)

    for {show, copy} <- [
          {~p"/quotes/#{quote}", ~p"/quotes/new?copy=#{quote.id}"},
          {~p"/orders/#{order}", ~p"/orders/new?copy=#{order.id}"},
          {~p"/invoices/#{invoice}", ~p"/invoices/new?copy=#{invoice.id}"},
          {~p"/rfqs/#{rfq}", ~p"/rfqs/new?copy=#{rfq.id}"},
          {~p"/purchase-orders/#{po}", ~p"/purchase-orders/new?copy=#{po.id}"},
          {~p"/bills/#{bill}", ~p"/bills/new?copy=#{bill.id}"}
        ] do
      {:ok, view, _html} = live(conn, show)
      assert has_element?(view, ~s|a[href="#{copy}"]|, "Duplicate")
    end

    {:ok, view, _html} = live(conn, ~p"/quotes/new?copy=#{quote.id}")
    assert has_element?(view, "#line-items", "$70.80") || has_element?(view, "#line-items", "$60")
    view |> form("#document-form") |> render_submit()
    {_path, _flash} = assert_redirect(view)

    assert [_, _] = Sales.list_quotes!(opts)

    {:ok, view, _html} = live(conn, ~p"/bills/new?copy=#{bill.id}")
    view |> form("#document-form") |> render_submit()
    {_path, _flash} = assert_redirect(view)
    assert length(Purchasing.list_bills!(opts)) == 2
  end

  test "leave policies: create, set entitlements, assign people", %{conn: conn, opts: opts} do
    annual = HR.create_leave_type!(%{name: "Annual", allowance_days: Decimal.new(20)}, opts)
    ada = HR.hire_employee!(%{first_name: "Ada"}, opts)

    {:ok, view, _html} = live(conn, ~p"/hr/leave-policies/new")
    view |> form("#policy-form", policy: %{name: "Senior"}) |> render_submit()
    [policy] = HR.list_leave_policies!(opts)
    assert_patch(view, ~p"/hr/leave-policies/#{policy}/rules")

    view
    |> form("#rules-form",
      rules: %{
        "0" => %{
          included: "true",
          leave_type_id: annual.id,
          days_per_year: "25",
          carry_over_days: "5"
        }
      }
    )
    |> render_submit()

    assert [%{rules: [%{days_per_year: days}]}] = HR.list_leave_policies!(opts)
    assert Decimal.eq?(days, 25)

    {:ok, view, _html} = live(conn, ~p"/hr/leave-policies/#{policy}/assign")
    view |> form("#assign-form", %{"employee_ids" => [ada.id]}) |> render_submit()
    assert HR.get_employee!(ada.id, opts).leave_policy_id == policy.id
    assert has_element?(view, "#policy-#{policy.id}", "1 person")
  end

  test "orders, invoices and bills print their delivery / goods received notes", %{
    conn: conn,
    opts: opts,
    party: party,
    widget: widget
  } do
    # Sales: an order delivered in two parts, then invoiced.
    order =
      %{customer_id: party.id, lines: [line(widget, "20")]}
      |> Sales.create_sales_order!(opts)
      |> Sales.confirm_sales_order!(opts)

    [order_line] = Ash.load!(order, :lines, opts).lines
    order = Sales.deliver_sales_order!(order, %{quantities: %{order_line.id => "1"}}, opts)
    order = Sales.deliver_sales_order!(order, %{}, opts)

    [first, second] =
      Sales.list_deliveries!(%{sales_order_id: order.id}, opts) |> Enum.sort_by(& &1.number)

    {:ok, view, _html} = live(conn, ~p"/orders/#{order}")
    assert has_element?(view, ~s|a#print-order[href="/orders/#{order.id}/print"]|)
    all = "/deliveries/print?ids=#{first.id},#{second.id}"
    assert has_element?(view, ~s|a#print-order-notes[href="#{all}"]|, "Delivery notes (2)")

    {:ok, printout, _html} = live(conn, all)
    assert has_element?(printout, "#dn-paper-#{first.id}", "DN-")
    assert has_element?(printout, "#dn-paper-#{second.id}", "DN-")

    invoice = Sales.invoice_sales_order!(order.id, opts)
    {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")
    assert has_element?(view, ~s|a#print-invoice-notes[href="#{all}"]|)

    # Purchases: a received order and its bill.
    po =
      %{supplier_id: party.id, lines: [line(widget, "5")]}
      |> Purchasing.create_purchase_order!(opts)
      |> Purchasing.place_purchase_order!(opts)
      |> Purchasing.receive_purchase_order!(%{}, opts)

    [grn] = Purchasing.list_goods_receipts!(%{purchase_order_id: po.id}, opts)

    {:ok, view, _html} = live(conn, ~p"/purchase-orders/#{po}")

    assert has_element?(
             view,
             ~s|a#print-po-notes[href="/goods-receipts/#{grn.id}/print"]|,
             "Goods received note"
           )

    bill = Purchasing.bill_purchase_order!(po.id, opts)
    {:ok, view, _html} = live(conn, ~p"/bills/#{bill}")
    assert has_element?(view, ~s|a#print-bill-notes[href="/goods-receipts/#{grn.id}/print"]|)

    {:ok, printout, _html} = live(conn, "/goods-receipts/print?ids=#{grn.id}")
    assert has_element?(printout, "#grn-paper-#{grn.id}", "Goods received note")
  end
end
