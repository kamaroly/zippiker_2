defmodule Zippiker.Reporting.Reports.Inventory do
  @moduledoc """
  Inventory and open orders: valuation from stock movements (quantities
  are signed, value is quantity × unit cost), count sheets, stock status
  and what is still to receive from suppliers or deliver to customers.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Catalog.Product
  alias Zippiker.Inventory.StockMovement
  alias Zippiker.Purchasing.PurchaseOrder
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.OpenItems
  alias Zippiker.Sales.SalesOrder

  # Valuation

  defp movements(ctx, filter) do
    query =
      StockMovement
      |> filter.()
      |> Ash.Query.load([:product, :warehouse, operation: [:party]])
      |> Ash.Query.sort(date: :asc, inserted_at: :asc)

    query =
      if ctx.branch_id,
        do: Ash.Query.filter(query, warehouse.branch_id == ^ctx.branch_id),
        else: query

    Context.read(query, ctx)
  end

  defp value(movement), do: Decimal.mult(movement.quantity, movement.unit_cost || Decimal.new(0))

  def valuation_summary(ctx) do
    as_of = ctx.to
    moves = movements(ctx, &Ash.Query.filter(&1, date <= ^as_of))
    grand = Context.sum(Enum.map(moves, &value/1))

    rows =
      moves
      |> Enum.group_by(& &1.product_id)
      |> Enum.map(fn {_id, moves} ->
        product = hd(moves).product
        quantity = Context.sum(Enum.map(moves, & &1.quantity))
        value = Context.sum(Enum.map(moves, &value/1))

        average =
          if Decimal.eq?(quantity, 0),
            do: nil,
            else: Decimal.round(Decimal.div(value, quantity), 2)

        row(
          [
            product.name,
            product.sku || "",
            quantity,
            average,
            value,
            percent(value, grand),
            product.unit_price,
            Decimal.mult(quantity, product.unit_price || Decimal.new(0))
          ],
          link: "/inventory/products/#{product.id}"
        )
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [
        col("Product"),
        col("SKU"),
        col("Quantity", :number),
        col("Average cost", :money),
        col("Asset value", :money),
        col("% of total", :percent),
        col("Sales price", :money),
        col("Retail value", :money)
      ],
      rows ++ OpenItems.footer(rows, 8, [4, 7])
    )
  end

  def valuation_detail(ctx) do
    before = movements(ctx, &Ash.Query.filter(&1, date < ^ctx.from))
    during = movements(ctx, &Ash.Query.filter(&1, date >= ^ctx.from and date <= ^ctx.to))
    opening = Enum.group_by(before, & &1.product_id)
    zero = Decimal.new(0)

    products =
      (before ++ during)
      |> Enum.map(& &1.product)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.name)

    by_product = Enum.group_by(during, & &1.product_id)

    rows =
      Enum.flat_map(products, fn product ->
        start = Map.get(opening, product.id, [])
        quantity = Context.sum(Enum.map(start, & &1.quantity))
        amount = Context.sum(Enum.map(start, &value/1))

        {lines, {closing_quantity, closing_value}} =
          Enum.map_reduce(Map.get(by_product, product.id, []), {quantity, amount}, fn move,
                                                                                      {q, v} ->
            q = Decimal.add(q, move.quantity)
            v = Decimal.add(v, value(move))

            {row(
               [
                 move.date,
                 Context.humanize(move.operation.kind),
                 move.operation.number,
                 Context.name(move.operation.party, ""),
                 move.warehouse && move.warehouse.name,
                 move.quantity,
                 move.unit_cost,
                 value(move),
                 q,
                 v
               ],
               depth: 1,
               link: "/inventory/operations/#{move.operation_id}"
             ), {q, v}}
          end)

        if lines == [] and Decimal.eq?(quantity, 0) and Decimal.eq?(amount, 0) do
          []
        else
          [
            heading(product.name, link: "/inventory/products/#{product.id}"),
            row(["", "Opening", nil, nil, nil, nil, nil, nil, quantity, amount], depth: 1)
          ] ++
            lines ++
            [
              subtotal([
                "Total #{product.name}",
                nil,
                nil,
                nil,
                nil,
                Decimal.sub(closing_quantity, quantity),
                nil,
                Decimal.sub(closing_value, amount),
                closing_quantity,
                closing_value
              ])
            ]
        end
      end)

    closing =
      rows
      |> Enum.filter(&(&1.kind == :subtotal))
      |> Enum.map(&Enum.at(&1.cells, 9))
      |> Context.sum()

    footer =
      if rows == [],
        do: [],
        else: [total(["Total", nil, nil, nil, nil, nil, nil, nil, nil, closing || zero])]

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col("Name"),
        col("Warehouse"),
        col("Quantity", :number),
        col("Cost", :money),
        col("Value", :money),
        col("Quantity on hand", :number),
        col("Asset value", :money)
      ],
      rows ++ footer
    )
  end

  def physical_worksheet(ctx) do
    as_of = ctx.today

    rows =
      ctx
      |> movements(&Ash.Query.filter(&1, date <= ^as_of))
      |> Enum.group_by(&{&1.warehouse_id, &1.product_id})
      |> Enum.map(fn {_key, [move | _] = moves} ->
        %{
          warehouse: (move.warehouse && move.warehouse.name) || "No warehouse",
          product: move.product,
          quantity: Context.sum(Enum.map(moves, & &1.quantity))
        }
      end)
      |> grouped(
        6,
        &{&1.warehouse, &1.warehouse},
        fn item ->
          row(
            [
              item.product.name,
              item.product.sku || "",
              item.product.unit || "",
              item.quantity,
              item.product.reorder_level,
              nil
            ],
            link: "/inventory/products/#{item.product.id}"
          )
        end,
        [3]
      )

    table(
      [
        col("Product"),
        col("SKU"),
        col("Unit"),
        col("On hand", :number),
        col("Reorder level", :number),
        col("Physical count", :blank)
      ],
      rows,
      note: "Print this sheet, count each shelf and write the quantity in the last column."
    )
  end

  def status(ctx) do
    on_order =
      ctx
      |> open_purchase_lines()
      |> Enum.group_by(& &1.line.product_id, & &1.open)
      |> Map.new(fn {id, values} -> {id, Context.sum(values)} end)

    committed =
      ctx
      |> open_sales_lines()
      |> Enum.group_by(& &1.line.product_id, & &1.open)
      |> Map.new(fn {id, values} -> {id, Context.sum(values)} end)

    zero = Decimal.new(0)

    rows =
      Product
      |> Ash.Query.filter(track_inventory? and is_nil(archived_at))
      |> Ash.Query.load(:on_hand)
      |> Ash.Query.sort(name: :asc)
      |> Context.read(ctx)
      |> Enum.map(fn product ->
        on_hand = product.on_hand || zero
        ordered = Map.get(on_order, product.id, zero)
        reserved = Map.get(committed, product.id, zero)
        available = Decimal.sub(on_hand, reserved)

        state =
          cond do
            Decimal.lt?(available, 0) ->
              "Short"

            product.reorder_level && Decimal.compare(available, product.reorder_level) != :gt ->
              "Reorder"

            true ->
              "OK"
          end

        row(
          [
            product.name,
            product.sku || "",
            on_hand,
            ordered,
            reserved,
            available,
            product.reorder_level,
            state
          ],
          link: "/inventory/products/#{product.id}"
        )
      end)

    table(
      [
        col("Product"),
        col("SKU"),
        col("On hand", :number),
        col("On purchase order", :number),
        col("On sales order", :number),
        col("Available", :number),
        col("Reorder level", :number),
        col("Status")
      ],
      rows
    )
  end

  # Open orders

  defp open_purchase_lines(ctx) do
    PurchaseOrder
    |> Ash.Query.filter(status in [:ordered, :partially_received])
    |> Context.branch(ctx)
    |> Ash.Query.load([:supplier, lines: [:product]])
    |> Ash.Query.sort(issued_on: :asc)
    |> Context.read(ctx)
    |> Enum.flat_map(fn order ->
      for line <- order.lines,
          open = Decimal.sub(line.quantity, line.received_quantity || Decimal.new(0)),
          Decimal.gt?(open, 0),
          do: %{order: order, line: line, open: open, amount: share(line, open)}
    end)
  end

  defp open_sales_lines(ctx) do
    SalesOrder
    |> Ash.Query.filter(status in [:confirmed, :partially_delivered])
    |> Context.branch(ctx)
    |> Ash.Query.load([:customer, lines: [:product]])
    |> Ash.Query.sort(issued_on: :asc)
    |> Context.read(ctx)
    |> Enum.flat_map(fn order ->
      for line <- order.lines,
          open = Decimal.sub(line.quantity, line.delivered_quantity || Decimal.new(0)),
          Decimal.gt?(open, 0),
          do: %{order: order, line: line, open: open, amount: share(line, open)}
    end)
  end

  # Net amount of the open part of a line.
  defp share(line, open) do
    if Decimal.eq?(line.quantity, 0),
      do: Decimal.new(0),
      else: line.subtotal |> Decimal.mult(open) |> Decimal.div(line.quantity) |> Decimal.round(2)
  end

  defp item_name(%{product: %{name: name}}), do: name
  defp item_name(line), do: line.description || "No product"

  defp order_line_row(%{order: order, line: line} = item, name, path, done) do
    row(
      [
        order.issued_on,
        order.number,
        name,
        line.quantity,
        done,
        item.open,
        item.amount
      ],
      link: "#{path}/#{order.id}"
    )
  end

  defp order_line_columns(name, done) do
    [
      col("Date", :date),
      col("Number"),
      col(name),
      col("Ordered", :number),
      col(done, :number),
      col("Open quantity", :number),
      col("Open amount", :money)
    ]
  end

  def open_purchase_order_detail(ctx) do
    rows =
      ctx
      |> open_purchase_lines()
      |> grouped(
        7,
        fn item ->
          name = Context.name(item.order.supplier)
          {name, name}
        end,
        &order_line_row(&1, item_name(&1.line), "/purchase-orders", &1.line.received_quantity),
        [5, 6],
        link: &Context.party_path(&1.order.supplier)
      )

    table(order_line_columns("Product", "Received"), rows)
  end

  def open_purchase_order_list(ctx) do
    rows =
      ctx
      |> open_purchase_lines()
      |> Enum.group_by(& &1.order.id)
      |> Enum.map(fn {id, [item | _] = items} ->
        order = item.order

        row(
          [
            order.issued_on,
            order.number,
            Context.name(order.supplier),
            order.expected_on,
            Context.humanize(order.status),
            Context.amount(order.total),
            Context.sum(Enum.map(items, & &1.amount))
          ],
          link: "/purchase-orders/#{id}"
        )
      end)
      |> Enum.sort_by(&hd(&1.cells), Date)

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Supplier"),
        col("Expected", :date),
        col("Status"),
        col("Total", :money),
        col("Open amount (net)", :money)
      ],
      rows ++ OpenItems.footer(rows, 7, [5, 6])
    )
  end

  def open_sales_orders_by_customer(ctx) do
    rows =
      ctx
      |> open_sales_lines()
      |> grouped(
        7,
        fn item ->
          name = Context.name(item.order.customer)
          {name, name}
        end,
        &order_line_row(&1, item_name(&1.line), "/orders", &1.line.delivered_quantity),
        [5, 6],
        link: &Context.party_path(&1.order.customer)
      )

    table(order_line_columns("Product", "Delivered"), rows)
  end

  def open_sales_orders_by_item(ctx) do
    rows =
      ctx
      |> open_sales_lines()
      |> grouped(
        7,
        fn item ->
          name = item_name(item.line)
          {name, name}
        end,
        &order_line_row(
          &1,
          Context.name(&1.order.customer),
          "/orders",
          &1.line.delivered_quantity
        ),
        [3, 4, 5, 6]
      )

    table(order_line_columns("Customer", "Delivered"), rows)
  end

  def sales_order_list(ctx) do
    rows =
      SalesOrder
      |> Ash.Query.filter(issued_on >= ^ctx.from and issued_on <= ^ctx.to)
      |> Context.branch(ctx)
      |> Ash.Query.load(:customer)
      |> Ash.Query.sort(issued_on: :asc, number: :asc)
      |> Context.read(ctx)
      |> Enum.map(fn order ->
        row(
          [
            order.issued_on,
            order.number,
            Context.name(order.customer),
            order.expected_on,
            Context.humanize(order.status),
            Context.amount(order.total)
          ],
          link: "/orders/#{order.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Customer"),
        col("Expected", :date),
        col("Status"),
        col("Amount", :money)
      ],
      rows ++ OpenItems.footer(rows, 6, [5])
    )
  end
end
