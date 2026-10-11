defmodule Zippiker.Reporting.Reports.Receivables do
  @moduledoc "Who owes you: ageing, balances, invoice lists, statements, terms and unbilled goods."
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Purchasing.Bill
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.OpenItems
  alias Zippiker.Sales.{Invoice, SalesOrder}

  def ageing_summary(ctx), do: OpenItems.ageing_summary(ctx, :ar)
  def ageing_detail(ctx), do: OpenItems.ageing_detail(ctx, :ar)
  def collections(ctx), do: OpenItems.collections(ctx)
  def balance_summary(ctx), do: OpenItems.balance_summary(ctx, :ar)
  def balance_detail(ctx), do: OpenItems.balance_detail(ctx, :ar)
  def invoice_list(ctx), do: OpenItems.list(ctx, :ar)
  def invoices_and_payments(ctx), do: OpenItems.with_payments(ctx, :ar)
  def open_invoices(ctx), do: OpenItems.open_by_party(ctx, :ar)

  @doc "Opening balance, invoiced, received and closing balance per customer."
  def statement_list(ctx) do
    opening = by_party(OpenItems.open(ctx, :ar, Date.add(ctx.from, -1)), & &1.open)
    closing = by_party(OpenItems.open(ctx, :ar, ctx.to), & &1.open)
    invoiced = by_party(OpenItems.issued(ctx, :ar), &Context.amount(&1.total))
    received = by_party(OpenItems.payments(ctx, :ar), &Context.amount(&1.amount))
    zero = Decimal.new(0)

    rows =
      [opening, closing, invoiced, received]
      |> Enum.flat_map(&Map.values/1)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(&Context.name/1)
      |> Enum.map(fn party ->
        value = fn map -> map |> Map.get(party.id, {party, zero}) |> elem(1) end

        row(
          [
            Context.name(party),
            party.email && to_string(party.email),
            value.(opening),
            value.(invoiced),
            value.(received),
            value.(closing)
          ],
          link: Context.party_path(party)
        )
      end)

    table(
      [
        col("Customer"),
        col("Email"),
        col("Opening balance", :money),
        col("Invoiced", :money),
        col("Received", :money),
        col("Closing balance", :money)
      ],
      rows ++ OpenItems.footer(rows, 6, [2, 3, 4, 5])
    )
  end

  defp by_party(items, value) do
    items
    |> Enum.reject(&is_nil(&1.party))
    |> Enum.group_by(& &1.party.id)
    |> Map.new(fn {id, group} ->
      {id, {hd(group).party, Context.sum(Enum.map(group, value))}}
    end)
  end

  @doc "Payment terms in use: days between issue and due date on invoices and bills."
  def terms_list(ctx) do
    days = fn resource ->
      resource
      |> Ash.Query.filter(status != :draft and not is_nil(due_on))
      |> Ash.Query.select([:issued_on, :due_on])
      |> Context.read(ctx)
      |> Enum.frequencies_by(&Date.diff(&1.due_on, &1.issued_on))
    end

    invoices = days.(Invoice)
    bills = days.(Bill)

    defaults =
      Zippiker.Accounts.LegalEntity
      |> Context.read(ctx)
      |> Enum.map(& &1.payment_terms_days)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    rows =
      (Map.keys(invoices) ++ Map.keys(bills) ++ MapSet.to_list(defaults))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn days ->
        row([
          term_name(days),
          Decimal.new(days),
          Decimal.new(Map.get(invoices, days, 0)),
          Decimal.new(Map.get(bills, days, 0)),
          if(days in defaults, do: "Company default", else: "")
        ])
      end)

    table(
      [
        col("Term"),
        col("Days", :number),
        col("Invoices", :number),
        col("Bills", :number),
        col("Note")
      ],
      rows
    )
  end

  defp term_name(days) when days <= 0, do: "Due on receipt"
  defp term_name(days), do: "Net #{days}"

  @doc "Delivered quantities on sales orders that have no invoice yet."
  def unbilled_charges(ctx) do
    lines =
      SalesOrder
      |> Ash.Query.filter(status in [:partially_delivered, :delivered] and is_nil(invoice.id))
      |> Context.branch(ctx)
      |> Ash.Query.load([:customer, lines: [:product]])
      |> Ash.Query.sort(issued_on: :asc)
      |> Context.read(ctx)
      |> Enum.flat_map(fn order ->
        for line <- order.lines, Decimal.gt?(line.delivered_quantity || Decimal.new(0), 0) do
          share = Decimal.div(line.delivered_quantity, line.quantity)
          %{order: order, line: line, amount: Decimal.mult(Context.amount(line.subtotal), share)}
        end
      end)

    rows =
      grouped(
        lines,
        7,
        fn %{order: order} ->
          name = Context.name(order.customer)
          {name, name}
        end,
        fn %{order: order, line: line, amount: amount} ->
          row(
            [
              order.issued_on,
              order.number,
              (line.product && line.product.name) || line.description,
              line.delivered_quantity,
              line.unit_price,
              Decimal.round(amount, 2),
              Context.humanize(order.status)
            ],
            link: "/orders/#{order.id}"
          )
        end,
        [5],
        link: &Context.party_path(&1.order.customer)
      )

    table(
      [
        col("Date", :date),
        col("Order"),
        col("Product/service"),
        col("Delivered", :number),
        col("Rate", :money),
        col("Unbilled amount", :money),
        col("Status")
      ],
      rows
    )
  end
end
