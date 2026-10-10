defmodule ZippikerWeb.PurchasingInventoryLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Accounts, Accounting, Catalog, Inventory, Parties, Purchasing, Sales}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    supplier = Parties.create_party!(%{kind: :organization, name: "Acme Supplies"}, opts)
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)

    widget =
      Catalog.create_product!(
        %{
          name: "Widget",
          kind: :goods,
          unit: "pcs",
          track_inventory?: true,
          unit_price: Decimal.new(20),
          cost_price: Decimal.new(5)
        },
        opts
      )

    %{supplier: supplier, customer: customer, widget: widget}
  end

  defp on_hand(opts, product),
    do: Catalog.get_product!(product.id, opts ++ [load: [:on_hand]]).on_hand

  test "every new page renders", %{conn: conn} do
    for path <-
          ~w(/orders /orders/new /purchase-orders /purchase-orders/new /bills /bills/new /inventory /inventory/adjust /inventory/operations /inventory/warehouses /inventory/warehouses/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "purchase order: create, place, receive part, bill, approve, pay", %{
    conn: conn,
    opts: opts,
    supplier: supplier,
    widget: widget
  } do
    {:ok, view, _html} = live(conn, ~p"/purchase-orders/new?supplier_id=#{supplier.id}")

    view
    |> form("#document-form",
      document: %{lines: %{"0" => %{product_id: widget.id, quantity: "10"}}}
    )
    |> render_change()

    # Purchase documents autofill the cost price: 10 × 5
    assert has_element?(view, "#line-items", "$50")

    view |> form("#document-form") |> render_submit()
    {path, _flash} = assert_redirect(view)

    {:ok, view, _html} = live(conn, path)
    view |> element("#place-po") |> render_click()

    [order] = Purchasing.list_purchase_orders!(opts)
    [line] = Ash.load!(order, :lines, opts).lines
    {:ok, view, _html} = live(conn, ~p"/purchase-orders/#{order}/receive")

    view
    |> form("#receive-form", receive: %{quantities: %{line.id => "6"}, reference: "DN-55"})
    |> render_submit()

    assert Decimal.eq?(on_hand(opts, widget), Decimal.new(6))
    assert has_element?(view, "#po-receipts", "DN-55")

    [receipt] = Purchasing.list_goods_receipts!(%{purchase_order_id: order.id}, opts)
    {:ok, list, _html} = live(conn, ~p"/goods-receipts")
    assert has_element?(list, "#notes-#{receipt.id}", "DN-55")

    {:ok, note, _html} = live(conn, ~p"/goods-receipts/#{receipt}/print")
    assert has_element?(note, "#grn-paper", "Goods received note")
    assert has_element?(note, "#grn-paper", "Acme Supplies")
    assert has_element?(note, "#grn-paper", "Widget")

    view |> element("#bill-po") |> render_click()
    {bill_path, _flash} = assert_redirect(view)

    {:ok, view, _html} = live(conn, bill_path)
    view |> element("#approve-bill") |> render_click()
    assert has_element?(view, "#pay-bill")

    [bill] = Purchasing.list_bills!(opts)
    {:ok, view, _html} = live(conn, ~p"/bills/#{bill}/payment")

    view
    |> form("#bill-payment-form", payment: %{amount: "50", method: "bank_transfer"})
    |> render_submit()

    assert Purchasing.get_bill!(bill.id, opts).status == :paid
    assert {:ok, _view, _html} = live(conn, ~p"/purchase-orders/#{order}/print")
  end

  test "a bill for services books to the chosen expense account", %{
    conn: conn,
    opts: opts,
    supplier: supplier
  } do
    Accounting.setup_books!(opts)
    rent = Enum.find(Accounting.list_accounts!(opts), &(&1.code == "6100"))

    {:ok, view, _html} = live(conn, ~p"/bills/new?supplier_id=#{supplier.id}")

    view
    |> form("#document-form",
      document: %{
        supplier_reference: "R-1",
        lines: %{
          "0" => %{
            description: "October rent",
            quantity: "1",
            unit_price: "900",
            expense_account_id: rent.id
          }
        }
      }
    )
    |> render_submit()

    [bill] = Purchasing.list_bills!(opts)
    Purchasing.approve_bill!(bill, opts)

    assert Decimal.eq?(
             Accounting.get_account!(rent.id, opts ++ [load: [:balance]]).balance,
             Decimal.new(900)
           )
  end

  test "adjusts stock from the stock page", %{conn: conn, opts: opts, widget: widget} do
    {:ok, view, _html} = live(conn, ~p"/inventory/adjust?product_id=#{widget.id}")

    view
    |> form("#adjust-form", adjustment: %{quantity: "12", unit_cost: "4", memo: "Opening stock"})
    |> render_submit()

    assert_patch(view)
    assert Decimal.eq?(on_hand(opts, widget), Decimal.new(12))
    assert has_element?(view, "#stock-#{widget.id}", "12")

    [operation] = Inventory.list_stock_operations!(%{}, opts)
    {:ok, view, _html} = live(conn, ~p"/inventory/operations/#{operation}")
    assert has_element?(view, "#operation-movements", "Widget")

    {:ok, _view, _html} =
      view |> element("#reverse-operation") |> render_click() |> follow_redirect(conn)

    assert Decimal.eq?(on_hand(opts, widget), Decimal.new(0))
    assert {:ok, _view, _html} = live(conn, ~p"/inventory/products/#{widget}")
  end

  test "adds a warehouse", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/inventory/warehouses/new")

    view
    |> form("#warehouse-form", warehouse: %{name: "Shop", code: "SHOP"})
    |> render_submit()

    assert_patch(view, ~p"/inventory/warehouses")
    assert Enum.any?(Inventory.list_warehouses!(opts), &(&1.code == "SHOP"))
  end

  test "quote → order → deliver → invoice from the screens", %{
    conn: conn,
    opts: opts,
    customer: customer,
    widget: widget
  } do
    Inventory.adjust_stock!(%{product_id: widget.id, quantity: "10"}, opts)

    quote =
      Sales.create_quote!(
        %{
          customer_id: customer.id,
          lines: [
            %{product_id: widget.id, description: "Widget", quantity: "3", unit_price: "20"}
          ]
        },
        opts
      )
      |> Sales.accept_quote!(opts)

    {:ok, view, _html} = live(conn, ~p"/quotes/#{quote}")
    view |> element("#order-quote") |> render_click()
    {order_path, _flash} = assert_redirect(view)

    {:ok, view, _html} = live(conn, order_path)
    view |> element("#confirm-order") |> render_click()

    [order] = Sales.list_sales_orders!(opts)
    [line] = Ash.load!(order, :lines, opts).lines

    # First part of the delivery…
    {:ok, view, _html} = live(conn, ~p"/orders/#{order}/deliver")

    view
    |> form("#deliver-form",
      deliver: %{quantities: %{line.id => "1"}, carrier: "DHL", tracking_number: "TRK-1"}
    )
    |> render_submit()

    assert Sales.get_sales_order!(order.id, opts).status == :partially_delivered
    assert Decimal.eq?(on_hand(opts, widget), Decimal.new(9))

    # …then the rest.
    {:ok, view, _html} = live(conn, ~p"/orders/#{order}/deliver")
    view |> form("#deliver-form") |> render_submit()
    assert Decimal.eq?(on_hand(opts, widget), Decimal.new(7))
    assert has_element?(view, "#order-deliveries li", "DN-")

    [first | _] =
      Sales.list_deliveries!(%{sales_order_id: order.id}, opts) |> Enum.sort_by(& &1.number)

    {:ok, note, _html} = live(conn, ~p"/deliveries/#{first}/print")
    assert has_element?(note, "#dn-paper", "Delivery note")
    assert has_element?(note, "#dn-paper", "TRK-1")

    {:ok, confirm_view, _html} = live(conn, ~p"/deliveries/#{first}/confirm")

    confirm_view
    |> form("#confirm-form", confirmation: %{received_by_name: "J. Doe"})
    |> render_submit()

    assert Sales.get_delivery!(first.id, opts).status == :delivered
    assert {:ok, _view, _html} = live(conn, ~p"/deliveries")

    view |> element("#invoice-order") |> render_click()
    {invoice_path, _flash} = assert_redirect(view)
    assert invoice_path =~ "/invoices/"

    assert {:ok, _view, _html} = live(conn, ~p"/orders/#{order}/print")
  end

  test "purchasing pages are refused when the module is off", %{
    conn: conn,
    organization: organization
  } do
    Accounts.set_plan_limits!(organization, %{enabled_modules: [:crm, :sales]}, authorize?: false)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/bills")
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/bills/new")
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/inventory")
    assert {:ok, _view, _html} = live(conn, ~p"/invoices/new")
  end
end
