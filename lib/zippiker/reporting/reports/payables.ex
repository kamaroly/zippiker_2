defmodule Zippiker.Reporting.Reports.Payables do
  @moduledoc "What you owe: ageing, balances, bills, payments, purchases and spending by supplier."
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Expenses.ExpenseItem
  alias Zippiker.Purchasing.{BillLine, GoodsReceipt, PurchaseOrder, Rfq}
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.OpenItems

  def ageing_summary(ctx), do: OpenItems.ageing_summary(ctx, :ap)
  def ageing_detail(ctx), do: OpenItems.ageing_detail(ctx, :ap)
  def balance_summary(ctx), do: OpenItems.balance_summary(ctx, :ap)
  def balance_detail(ctx), do: OpenItems.balance_detail(ctx, :ap)
  def bills_and_payments(ctx), do: OpenItems.with_payments(ctx, :ap)
  def bill_payments(ctx), do: OpenItems.payment_list(ctx, :ap)
  def unpaid_bills(ctx), do: OpenItems.open_by_party(ctx, :ap)

  def cheque_detail(ctx) do
    rows =
      ctx
      |> OpenItems.payments(:ap)
      |> Enum.filter(&(&1.method == :cheque))
      |> Enum.map(fn payment ->
        row(
          [
            payment.paid_on,
            payment.reference || "",
            Context.name(payment.party),
            payment.document.number,
            Context.amount(payment.amount)
          ],
          link: "/bills/#{payment.document.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col("Cheque number"),
        col("Payee"),
        col("Bill"),
        col("Amount", :money)
      ],
      rows ++ OpenItems.footer(rows, 5, [4])
    )
  end

  def purchases_by_product(ctx) do
    rows =
      ctx
      |> bill_lines()
      |> grouped(
        7,
        fn line ->
          name = product_name(line)
          {name, name}
        end,
        &line_row(&1, Context.name(&1.bill.supplier)),
        [4, 6]
      )

    table(line_columns("Supplier"), rows)
  end

  def purchases_by_supplier(ctx) do
    rows =
      ctx
      |> bill_lines()
      |> grouped(
        7,
        fn line ->
          name = Context.name(line.bill.supplier)
          {name, name}
        end,
        &line_row(&1, product_name(&1)),
        [4, 6],
        link: &Context.party_path(&1.bill.supplier)
      )

    table(line_columns("Product/service"), rows)
  end

  defp bill_lines(ctx) do
    query =
      BillLine
      |> Ash.Query.filter(
        bill.status != :draft and bill.status != :void and bill.issued_on >= ^ctx.from and
          bill.issued_on <= ^ctx.to
      )
      |> Ash.Query.load([:product, bill: [:supplier]])

    query =
      if ctx.branch_id,
        do: Ash.Query.filter(query, bill.branch_id == ^ctx.branch_id),
        else: query

    query
    |> Context.read(ctx)
    |> Enum.sort_by(&{&1.bill.issued_on, &1.bill.number, &1.position})
  end

  defp line_row(line, name) do
    row(
      [
        line.bill.issued_on,
        line.bill.number,
        name,
        line.description,
        line.quantity,
        line.unit_price,
        Context.amount(line.subtotal)
      ],
      link: "/bills/#{line.bill_id}"
    )
  end

  defp line_columns(name) do
    [
      col("Date", :date),
      col("Bill"),
      col(name),
      col("Description"),
      col("Quantity", :number),
      col("Rate", :money),
      col("Amount", :money)
    ]
  end

  defp product_name(%{product: %{name: name}}), do: name
  defp product_name(_line), do: "No product (expenses)"

  def purchase_list(ctx) do
    orders =
      PurchaseOrder
      |> Ash.Query.filter(status != :draft and issued_on >= ^ctx.from and issued_on <= ^ctx.to)
      |> Context.branch(ctx)
      |> Ash.Query.load(:supplier)
      |> Context.read(ctx)
      |> Enum.map(&purchase_row(&1, "Purchase order", "/purchase-orders"))

    bills =
      ctx
      |> OpenItems.issued(:ap)
      |> Enum.map(&purchase_row(&1, "Bill", "/bills"))

    rows =
      Enum.sort_by(orders ++ bills, &{hd(&1.cells), Enum.at(&1.cells, 2)}, fn {a, x}, {b, y} ->
        case Date.compare(a, b) do
          :lt -> true
          :gt -> false
          :eq -> x <= y
        end
      end)

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col("Supplier"),
        col("Status"),
        col("Amount", :money)
      ],
      rows
    )
  end

  defp purchase_row(document, type, path) do
    row(
      [
        document.issued_on,
        type,
        document.number,
        Context.name(document.supplier),
        Context.humanize(document.status),
        Context.amount(document.total)
      ],
      link: "#{path}/#{document.id}"
    )
  end

  def transactions_by_supplier(ctx) do
    in_period = fn resource, :issued_on ->
      resource
      |> Ash.Query.filter(issued_on >= ^ctx.from and issued_on <= ^ctx.to)
      |> Ash.Query.load(:supplier)
      |> Context.read(ctx)
    end

    received =
      GoodsReceipt
      |> Ash.Query.filter(received_on >= ^ctx.from and received_on <= ^ctx.to)
      |> Ash.Query.load(:supplier)
      |> Context.read(ctx)

    rfqs =
      for rfq <- in_period.(Rfq, :issued_on),
          do: item(rfq.supplier, rfq.issued_on, "Request for quotation", rfq, "/rfqs", rfq.total)

    orders =
      for order <- in_period.(PurchaseOrder, :issued_on),
          do:
            item(
              order.supplier,
              order.issued_on,
              "Purchase order",
              order,
              "/purchase-orders",
              order.total
            )

    receipts =
      for receipt <- received,
          do:
            item(
              receipt.supplier,
              receipt.received_on,
              "Goods received",
              receipt,
              "/goods-receipts",
              nil
            )

    bills =
      for bill <- OpenItems.issued(ctx, :ap),
          do: item(bill.supplier, bill.issued_on, "Bill", bill, "/bills", bill.total)

    payments =
      for payment <- OpenItems.payments(ctx, :ap),
          do: %{
            party: payment.party,
            date: payment.paid_on,
            type: "Bill payment",
            number: payment.reference || payment.document.number,
            status: Context.humanize(payment.method),
            link: "/bills/#{payment.document.id}",
            amount: Context.amount(payment.amount)
          }

    rows = transactions_table(rfqs ++ orders ++ receipts ++ bills ++ payments)
    table(transaction_columns(), rows)
  end

  defp item(party, date, type, document, path, amount) do
    %{
      party: party,
      date: date,
      type: type,
      number: document.number,
      status: Context.humanize(document.status),
      link: "#{path}/#{document.id}",
      amount: amount && Context.amount(amount)
    }
  end

  @doc "Transactions grouped by party, in date order."
  def transactions_table(items, group \\ nil) do
    group =
      group ||
        fn item ->
          name = Context.name(item.party)
          {name, name}
        end

    items
    |> Enum.sort_by(& &1.date, Date)
    |> grouped(
      6,
      group,
      &row([&1.date, &1.type, &1.number, Context.name(&1.party), &1.status, &1.amount],
        link: &1.link
      ),
      [],
      link: &Context.party_path(&1.party)
    )
  end

  def transaction_columns do
    [
      col("Date", :date),
      col("Type"),
      col("Number"),
      col("Name"),
      col("Status"),
      col("Amount", :money)
    ]
  end

  @doc "Bill spending per supplier plus expense claim spending per merchant."
  def expenses_by_supplier(ctx) do
    bills =
      ctx
      |> OpenItems.issued(:ap)
      |> Enum.group_by(& &1.supplier_id)
      |> Enum.map(fn {_id, bills} ->
        supplier = hd(bills).supplier

        row(
          [
            Context.name(supplier),
            "Bills",
            Context.sum(Enum.map(bills, & &1.subtotal))
          ],
          link: Context.party_path(supplier)
        )
      end)

    claims =
      ExpenseItem
      |> Ash.Query.filter(
        spent_on >= ^ctx.from and spent_on <= ^ctx.to and
          claim.status in [:approved, :reimbursed]
      )
      |> Context.read(ctx)
      |> Enum.group_by(&String.trim(&1.merchant || ""))
      |> Enum.map(fn {merchant, items} ->
        row([
          if(merchant == "", do: "Unnamed merchant", else: merchant),
          "Expense claims",
          Context.sum(Enum.map(items, & &1.amount))
        ])
      end)

    rows = Enum.sort_by(bills ++ claims, &Enum.at(&1.cells, 2), {:desc, Decimal})

    table(
      [col("Supplier / merchant"), col("Source"), col("Amount", :money)],
      rows ++ OpenItems.footer(rows, 3, [2]),
      note: "Bills are counted before tax."
    )
  end
end
