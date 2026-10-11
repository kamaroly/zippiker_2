defmodule Zippiker.Reporting.Reports.Tax do
  @moduledoc """
  Sales tax (VAT): output tax on invoice lines, input tax on bill lines,
  per tax code, with exceptions and the liability from the ledger.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Accounting.Reports.Balances
  alias Zippiker.Purchasing.BillLine
  alias Zippiker.Reporting.Context
  alias Zippiker.Sales.InvoiceLine

  defp items(ctx) do
    sales =
      InvoiceLine
      |> Ash.Query.filter(
        invoice.status in [:issued, :paid] and invoice.issued_on >= ^ctx.from and
          invoice.issued_on <= ^ctx.to
      )
      |> branch(ctx, :invoice)
      |> Ash.Query.load([:tax_rate, product: [:tax_rate], invoice: [:customer]])
      |> Context.read(ctx)
      |> Enum.map(&item(&1, &1.invoice, &1.invoice.customer, :sales, "Invoice", "/invoices"))

    purchases =
      BillLine
      |> Ash.Query.filter(
        bill.status in [:open, :paid] and bill.issued_on >= ^ctx.from and
          bill.issued_on <= ^ctx.to
      )
      |> branch(ctx, :bill)
      |> Ash.Query.load([:tax_rate, product: [:tax_rate], bill: [:supplier]])
      |> Context.read(ctx)
      |> Enum.map(&item(&1, &1.bill, &1.bill.supplier, :purchases, "Bill", "/bills"))

    Enum.sort_by(sales ++ purchases, &{&1.date, &1.number}, fn {a, x}, {b, y} ->
      case Date.compare(a, b) do
        :lt -> true
        :gt -> false
        :eq -> x <= y
      end
    end)
  end

  defp branch(query, %{branch_id: nil}, _parent), do: query

  defp branch(query, %{branch_id: id}, :invoice),
    do: Ash.Query.filter(query, invoice.branch_id == ^id)

  defp branch(query, %{branch_id: id}, :bill), do: Ash.Query.filter(query, bill.branch_id == ^id)

  defp item(line, document, party, side, type, path) do
    %{
      line: line,
      side: side,
      date: document.issued_on,
      type: type,
      number: document.number,
      party: party,
      description: line.description,
      net: Context.amount(line.subtotal),
      percent: line.tax_percent || Decimal.new(0),
      tax: Context.amount(line.tax_amount),
      code: code(line.tax_rate),
      link: "#{path}/#{document.id}"
    }
  end

  defp code(nil), do: "No tax code"
  defp code(rate), do: rate.name

  defp item_row(item, extra \\ []) do
    row(
      [
        item.date,
        item.type,
        item.number,
        Context.name(item.party),
        item.description,
        item.net,
        item.percent,
        item.tax
      ] ++ extra,
      link: item.link
    )
  end

  defp item_columns do
    [
      col("Date", :date),
      col("Type"),
      col("Number"),
      col("Name"),
      col("Description"),
      col("Net amount", :money),
      col("Rate", :percent),
      col("Tax", :money)
    ]
  end

  def detail(ctx) do
    rows =
      ctx
      |> items()
      |> Enum.filter(&(Decimal.gt?(&1.tax, 0) or &1.line.tax_rate_id))
      |> grouped(
        8,
        fn item ->
          side = if item.side == :sales, do: "Output tax (sales)", else: "Input tax (purchases)"
          {{item.side, item.code}, "#{side} · #{item.code}"}
        end,
        &item_row/1,
        [5, 7],
        total_label: "Total (output and input)"
      )

    table(item_columns(), rows)
  end

  def by_tax_code(ctx) do
    rows = ctx |> items() |> grouped(8, &{&1.code, &1.code}, &item_row/1, [5, 7])
    table(item_columns(), rows)
  end

  def summary(ctx) do
    rows =
      ctx
      |> items()
      |> Enum.group_by(& &1.code)
      |> Enum.map(fn {code, items} ->
        side = fn side, field ->
          items
          |> Enum.filter(&(&1.side == side))
          |> Enum.map(&Map.get(&1, field))
          |> Context.sum()
        end

        rate = Enum.find_value(items, &(&1.line.tax_rate && &1.line.tax_rate.rate))
        output = side.(:sales, :tax)
        input = side.(:purchases, :tax)

        row([
          code,
          rate,
          side.(:sales, :net),
          output,
          side.(:purchases, :net),
          input,
          Decimal.sub(output, input)
        ])
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [
        col("Tax code"),
        col("Rate", :percent),
        col("Sales (net)", :money),
        col("Output tax", :money),
        col("Purchases (net)", :money),
        col("Input tax", :money),
        col("Net tax", :money)
      ],
      if(rows == [], do: [], else: rows ++ [total(totals(rows, 7, [2, 3, 4, 5, 6], "Total"))]),
      note: "Net tax is output tax minus input tax: positive means you owe it."
    )
  end

  def exceptions(ctx) do
    rows =
      for item <- items(ctx), issue = issue(item), do: item_row(item, [issue])

    table(item_columns() ++ [col("Issue")], rows,
      note:
        "Checks that each line's rate matches its tax code, that tax is never charged " <>
          "without a code, and that the code matches the product's default."
    )
  end

  defp issue(%{line: line, percent: percent}) do
    cond do
      line.tax_rate && not Decimal.eq?(percent, line.tax_rate.rate) ->
        "Line rate #{percent}% differs from #{line.tax_rate.name} (#{line.tax_rate.rate}%)"

      is_nil(line.tax_rate) and Decimal.gt?(percent, 0) ->
        "Tax charged without a tax code"

      line.product && line.product.tax_rate_id && line.tax_rate_id != line.product.tax_rate_id ->
        "Tax code differs from the product's default (#{code(line.product.tax_rate)})"

      true ->
        nil
    end
  end

  @doc "Tax collected and recoverable in the period, and the balance owed, from the ledger."
  def liability(ctx) do
    period = Balances.accounts(ctx.tenant, ctx.from, ctx.to, ctx.branch_id)
    closing = Balances.accounts(ctx.tenant, nil, ctx.to, ctx.branch_id)
    find = fn rows, key -> Enum.find(rows, &(&1.account.system_key == key)) end
    zero = Decimal.new(0)

    payable = find.(period, :tax_payable)
    receivable = find.(period, :tax_receivable)
    collected = if payable, do: payable.credits, else: zero
    paid_over = if payable, do: payable.debits, else: zero
    recoverable = if receivable, do: receivable.debits, else: zero
    recovered = if receivable, do: receivable.credits, else: zero

    payable_balance =
      case find.(closing, :tax_payable) do
        nil -> zero
        row -> Balances.normal(row)
      end

    receivable_balance =
      case find.(closing, :tax_receivable) do
        nil -> zero
        row -> Balances.normal(row)
      end

    table(
      [col("Item"), col("Amount", :money)],
      [
        heading("This period"),
        row(["Output tax collected on sales", collected], depth: 1),
        row(["Input tax on purchases", recoverable], depth: 1),
        subtotal(["Net tax for the period", Decimal.sub(collected, recoverable)]),
        row(["Tax paid or adjusted (payable account)", paid_over], depth: 1),
        row(["Input tax recovered or adjusted", recovered], depth: 1),
        heading("Balance on #{Context.format_date(ctx.to)}"),
        row(["Sales tax payable", payable_balance], depth: 1),
        row(["Input tax receivable", receivable_balance], depth: 1),
        total(["Net tax liability", Decimal.sub(payable_balance, receivable_balance)])
      ]
    )
  end
end
