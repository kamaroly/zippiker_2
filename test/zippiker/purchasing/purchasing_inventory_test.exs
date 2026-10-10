defmodule Zippiker.PurchasingInventoryTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounting, Catalog, Inventory, Parties, Purchasing, Sales}

  setup do
    {user, organization} = workspace_fixture()
    opts = [actor: user, tenant: organization]
    supplier = Parties.create_party!(%{kind: :organization, name: "Acme Supplies"}, opts)
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
    vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(18)}, opts)

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

    %{opts: opts, supplier: supplier, customer: customer, vat: vat, widget: widget}
  end

  defp d(value), do: Decimal.new(value)

  defp balance(opts, key) do
    Accounting.list_accounts!(opts) |> Enum.find(&(&1.system_key == key)) |> Map.fetch!(:balance)
  end

  defp product(opts, product), do: Catalog.get_product!(product.id, opts ++ [load: [:on_hand]])

  defp order(%{opts: opts, supplier: supplier, widget: widget, vat: vat}, quantity, price) do
    %{
      supplier_id: supplier.id,
      lines: [
        %{
          product_id: widget.id,
          description: "Widget",
          quantity: quantity,
          unit_price: price,
          tax_rate_id: vat.id
        }
      ]
    }
    |> Purchasing.create_purchase_order!(opts)
    |> Purchasing.place_purchase_order!(opts)
  end

  defp assert_books_balance(opts) do
    tb = Accounting.trial_balance!(nil, opts)
    assert Decimal.eq?(tb.debit, tb.credit)
    assert Accounting.balance_sheet!(nil, opts).balanced?
  end

  test "only goods can be stock-tracked", %{opts: opts} do
    assert {:error, %Ash.Error.Invalid{}} =
             Catalog.create_product(%{name: "Consulting", track_inventory?: true}, opts)
  end

  test "receiving a purchase order brings stock in at cost", %{opts: opts} = context do
    po = order(context, "10", "5")
    assert po.number =~ ~r/^PO-\d{4}-0001$/

    [line] = Ash.load!(po, :lines, opts).lines

    po =
      Purchasing.receive_purchase_order!(
        po,
        %{quantities: %{line.id => "4"}, reference: "DN-77"},
        opts
      )

    assert po.status == :partially_received
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(4))

    po = Purchasing.receive_purchase_order!(po, %{}, opts)
    assert po.status == :received

    widget = product(opts, context.widget)
    assert Decimal.eq?(widget.on_hand, d(10))
    assert Decimal.eq?(widget.average_cost, d(5))
    assert Decimal.eq?(balance(opts, :inventory), d(50))
    assert Decimal.eq?(balance(opts, :grni), d(50))

    assert {:error, _} = Purchasing.receive_purchase_order(po, %{}, opts)

    [second, grn] = Purchasing.list_goods_receipts!(%{purchase_order_id: po.id}, opts)
    assert grn.number =~ ~r/^GRN-\d{4}-0001$/
    assert second.number =~ ~r/^GRN-\d{4}-0002$/
    assert grn.supplier_reference == "DN-77"
    assert grn.supplier_id == context.supplier.id
    assert [%{quantity: four}] = Ash.load!(grn, :lines, opts).lines
    assert Decimal.eq?(four, d(4))

    [movement | _] = Inventory.list_stock_operations!(%{kind: :receipt}, opts)
    assert movement.number =~ ~r/^MV-/
  end

  test "average cost is weighted by quantity", %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)
    context |> order("10", "7") |> Purchasing.receive_purchase_order!(%{}, opts)

    widget = product(opts, context.widget)
    assert Decimal.eq?(widget.on_hand, d(20))
    assert Decimal.eq?(widget.average_cost, d(6))
  end

  test "a bill from a received order clears GRNI; paying it clears payables",
       %{opts: opts} = context do
    po = context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    bill =
      po.id
      |> Purchasing.bill_purchase_order!(opts)
      |> Purchasing.update_bill!(%{supplier_reference: "AS-991"}, opts)
      |> Purchasing.approve_bill!(opts)

    assert bill.status == :open
    assert bill.number =~ ~r/^BILL-\d{4}-0001$/
    assert Decimal.eq?(balance(opts, :grni), d(0))
    assert Decimal.eq?(balance(opts, :tax_receivable), d(9))
    assert Decimal.eq?(balance(opts, :payable), d(59))

    assert {:error, _} = Purchasing.bill_purchase_order(po.id, opts)

    payment =
      Purchasing.record_bill_payment!(
        %{bill_id: bill.id, amount: Money.new!(:USD, 59), method: :bank_transfer},
        opts
      )

    assert Purchasing.get_bill!(bill.id, opts).status == :paid
    assert Decimal.eq?(balance(opts, :payable), d(0))
    assert Decimal.eq?(balance(opts, :bank), d(-59))

    assert {:error, _} = Purchasing.void_bill(Purchasing.get_bill!(bill.id, opts), opts)
    Purchasing.delete_bill_payment!(payment, opts)
    assert Purchasing.get_bill!(bill.id, opts).status == :open
    assert_books_balance(opts)
  end

  test "price differences between order and bill go to cost of sales", %{opts: opts} = context do
    po = context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)
    bill = Purchasing.bill_purchase_order!(po.id, opts) |> Ash.load!(:lines, opts)
    [line] = bill.lines

    bill
    |> Purchasing.update_bill!(
      %{lines: [%{id: line.id, unit_price: "6", quantity: "10", description: "Widget"}]},
      opts
    )
    |> Purchasing.approve_bill!(opts)

    assert Decimal.eq?(balance(opts, :grni), d(0))
    assert Decimal.eq?(balance(opts, :cost_of_sales), d(10))
  end

  test "a bill without an order brings stock in; voiding takes it back",
       %{opts: opts} = context do
    Accounting.setup_books!(opts)
    rent = Enum.find(Accounting.list_accounts!(opts), &(&1.code == "6100"))

    bill =
      Purchasing.create_bill!(
        %{
          supplier_id: context.supplier.id,
          lines: [
            %{
              product_id: context.widget.id,
              description: "Widget",
              quantity: "3",
              unit_price: "8"
            },
            %{
              description: "Storage rent",
              quantity: "1",
              unit_price: "100",
              expense_account_id: rent.id
            }
          ]
        },
        opts
      )
      |> Purchasing.approve_bill!(opts)

    widget = product(opts, context.widget)
    assert Decimal.eq?(widget.on_hand, d(3))
    assert Decimal.eq?(widget.average_cost, d(8))
    assert [%{status: :received}] = Purchasing.list_goods_receipts!(%{bill_id: bill.id}, opts)
    assert Decimal.eq?(balance(opts, :inventory), d(24))

    assert Decimal.eq?(
             Accounting.get_account!(rent.id, opts ++ [load: [:balance]]).balance,
             d(100)
           )

    assert Decimal.eq?(balance(opts, :payable), d(124))

    Purchasing.void_bill!(bill, opts)
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(0))
    assert [%{status: :cancelled}] = Purchasing.list_goods_receipts!(%{bill_id: bill.id}, opts)
    assert Decimal.eq?(balance(opts, :inventory), d(0))
    assert Decimal.eq?(balance(opts, :payable), d(0))
    assert_books_balance(opts)
  end

  test "issuing an invoice ships goods at average cost; voiding returns them",
       %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    invoice =
      %{
        customer_id: context.customer.id,
        lines: [
          %{product_id: context.widget.id, description: "Widget", quantity: "4", unit_price: "20"}
        ]
      }
      |> Sales.create_invoice!(opts)
      |> Sales.issue_invoice!(opts)

    assert Decimal.eq?(product(opts, context.widget).on_hand, d(6))
    assert Decimal.eq?(balance(opts, :cost_of_sales), d(20))
    assert Decimal.eq?(balance(opts, :inventory), d(30))

    [delivery] = Inventory.list_stock_operations!(%{kind: :delivery}, opts)
    assert delivery.source == :invoice
    assert [%{status: :shipped}] = Sales.list_deliveries!(%{invoice_id: invoice.id}, opts)

    Sales.void_invoice!(invoice, opts)
    assert [%{status: :cancelled}] = Sales.list_deliveries!(%{invoice_id: invoice.id}, opts)
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(10))
    assert Decimal.eq?(balance(opts, :cost_of_sales), d(0))
    assert_books_balance(opts)
  end

  test "quote → order → delivery → invoice ships once", %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    quote =
      Sales.create_quote!(
        %{
          customer_id: context.customer.id,
          lines: [
            %{
              product_id: context.widget.id,
              description: "Widget",
              quantity: "2",
              unit_price: "20"
            }
          ]
        },
        opts
      )
      |> Sales.accept_quote!(opts)

    order = Sales.order_quote!(quote.id, opts)
    assert order.number =~ ~r/^SO-/
    assert {:error, _} = Sales.order_quote(quote.id, opts)
    assert {:error, _} = Sales.deliver_sales_order(order, opts)

    order = order |> Sales.confirm_sales_order!(opts) |> Sales.deliver_sales_order!(opts)
    assert order.status == :delivered
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(8))

    order.id |> Sales.invoice_sales_order!(opts) |> Sales.issue_invoice!(opts)
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(8))
    assert {:error, _} = Sales.invoice_sales_order(order.id, opts)
    assert_books_balance(opts)
  end

  test "orders deliver in parts; the invoice ships what's left", %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    order =
      %{
        customer_id: context.customer.id,
        lines: [
          %{product_id: context.widget.id, description: "Widget", quantity: "5", unit_price: "20"}
        ]
      }
      |> Sales.create_sales_order!(opts)
      |> Sales.confirm_sales_order!(opts)

    [line] = Ash.load!(order, :lines, opts).lines

    order =
      Sales.deliver_sales_order!(
        order,
        %{quantities: %{line.id => "2"}, carrier: "DHL", tracking_number: "DHL 123"},
        opts
      )

    assert order.status == :partially_delivered
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(8))

    [note] = Sales.list_deliveries!(%{sales_order_id: order.id}, opts)
    assert note.number =~ ~r/^DN-/
    assert note.customer_id == context.customer.id
    assert note.tracking_number == "DHL 123"

    note = Sales.confirm_delivery!(note, %{received_by_name: "J. Doe"}, opts)
    assert note.status == :delivered
    assert note.delivered_on == Date.utc_today()

    assert {:error, _} = Sales.update_sales_order(order, %{notes: "x"}, opts)

    order.id |> Sales.invoice_sales_order!(opts) |> Sales.issue_invoice!(opts)
    assert Sales.get_sales_order!(order.id, opts).status == :delivered
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(5))
    assert_books_balance(opts)
  end

  test "invoicing an undelivered order ships it", %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    order =
      %{
        customer_id: context.customer.id,
        lines: [
          %{product_id: context.widget.id, description: "Widget", quantity: "3", unit_price: "20"}
        ]
      }
      |> Sales.create_sales_order!(opts)
      |> Sales.confirm_sales_order!(opts)

    order.id |> Sales.invoice_sales_order!(opts) |> Sales.issue_invoice!(opts)

    assert Sales.get_sales_order!(order.id, opts).status == :delivered
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(7))
  end

  test "adjustments post to inventory adjustments and can be reversed", %{opts: opts} = context do
    context |> order("10", "5") |> Purchasing.receive_purchase_order!(%{}, opts)

    adjustment =
      Inventory.adjust_stock!(
        %{product_id: context.widget.id, quantity: "-2", memo: "Damaged"},
        opts
      )

    assert adjustment.number =~ ~r/^ADJ-/
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(8))
    assert Decimal.eq?(balance(opts, :inventory_adjustment), d(10))

    Inventory.reverse_stock_operation!(adjustment.id, opts)
    assert Decimal.eq?(product(opts, context.widget).on_hand, d(10))
    assert Decimal.eq?(balance(opts, :inventory_adjustment), d(0))
    assert {:error, _} = Inventory.reverse_stock_operation(adjustment.id, opts)
    assert_books_balance(opts)
  end

  test "stock levels per warehouse and the summary", %{opts: opts} = context do
    second = Inventory.create_warehouse!(%{name: "Shop", code: "SHOP"}, opts)
    main = Inventory.default_warehouse!(opts)

    Inventory.adjust_stock!(
      %{product_id: context.widget.id, quantity: "5", warehouse_id: main.id},
      opts
    )

    Inventory.adjust_stock!(
      %{product_id: context.widget.id, quantity: "2", warehouse_id: second.id},
      opts
    )

    assert [%{quantity: shop}] = Inventory.stock_levels!(%{warehouse_id: second.id}, opts)
    assert Decimal.eq?(shop, d(2))
    assert [%{quantity: all}] = Inventory.stock_levels!(%{}, opts)
    assert Decimal.eq?(all, d(7))

    summary = Inventory.inventory_summary!(opts)
    assert summary.tracked == 1
    assert Decimal.eq?(summary.value, d(35))
  end

  test "payables summary", %{opts: opts} = context do
    po = context |> order("10", "5")
    po.id |> Purchasing.bill_purchase_order!(opts) |> Purchasing.approve_bill!(opts)

    summary = Purchasing.payables_summary!(opts)
    assert Money.equal?(summary.payable, Money.new!(:USD, 59))
    assert summary.orders_to_receive == 1
  end

  test "members can't approve bills", %{opts: opts, supplier: supplier} do
    [tenant: organization] = Keyword.take(opts, [:tenant])
    member = member_fixture(organization)

    bill =
      Purchasing.create_bill!(
        %{
          supplier_id: supplier.id,
          lines: [%{description: "Paper", quantity: "1", unit_price: "10"}]
        },
        opts
      )

    assert {:error, %Ash.Error.Forbidden{}} =
             Purchasing.approve_bill(bill, actor: member, tenant: organization)
  end
end
