defmodule Zippiker.Reporting.Reports.Financial do
  @moduledoc """
  Financial statements from the journal: balance sheets, profit and loss in
  its column layouts, cash flows, changes in equity and the business
  snapshot. Account balances come from `Accounting.Reports.Balances`.
  """
  import Zippiker.Reporting.Table

  alias Zippiker.Accounting.Reports.Balances
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.Ledger

  @cash_keys [:cash, :bank, :mobile_money]
  @cost_of_sales_keys [:cost_of_sales, :inventory_adjustment, :production_overhead]

  # Balance sheets

  def balance_sheet(ctx), do: balance_sheets(ctx, [{"Total", ctx.to}])

  def balance_sheet_comparison(ctx) do
    previous = Date.shift(ctx.to, year: -1)

    balance_sheets(ctx, [{format(ctx.to), ctx.to}, {format(previous), previous}], change?: true)
  end

  def balance_sheet_detail(ctx) do
    from = Date.new!(ctx.to.year, 1, 1)
    Ledger.account_detail(%{ctx | from: from}, [:asset, :liability, :equity], opening?: true)
  end

  def balance_sheet_summary(ctx) do
    rows = Balances.accounts(ctx.tenant, nil, ctx.to, ctx.branch_id)
    by = fn filter -> rows |> Enum.filter(filter) |> Enum.map(&Balances.normal/1) |> sum() end
    key = fn keys -> fn row -> row.account.system_key in keys end end

    cash = by.(key.(@cash_keys))
    receivable = by.(key.([:receivable]))
    inventory = by.(key.([:inventory]))
    assets = by.(&(&1.account.type == :asset))

    other_assets =
      assets |> Decimal.sub(cash) |> Decimal.sub(receivable) |> Decimal.sub(inventory)

    payable = by.(key.([:payable]))
    liabilities = by.(&(&1.account.type == :liability))
    equity = by.(&(&1.account.type == :equity))

    earnings =
      Decimal.sub(by.(&(&1.account.type == :income)), by.(&(&1.account.type == :expense)))

    equity_total = Decimal.add(equity, earnings)

    table(
      [col("Category"), col("Total", :money)],
      [
        heading("Assets"),
        row(["Cash and bank", cash], depth: 1),
        row(["Accounts receivable", receivable], depth: 1),
        row(["Inventory", inventory], depth: 1),
        row(["Other assets", other_assets], depth: 1),
        subtotal(["Total assets", assets]),
        heading("Liabilities and equity"),
        row(["Accounts payable", payable], depth: 1),
        row(["Other liabilities", Decimal.sub(liabilities, payable)], depth: 1),
        subtotal(["Total liabilities", liabilities], depth: 1),
        row(["Equity", equity], depth: 1),
        row(["Current earnings", earnings], depth: 1),
        subtotal(["Total equity", equity_total], depth: 1),
        total(["Total liabilities and equity", Decimal.add(liabilities, equity_total)])
      ]
    )
  end

  defp balance_sheets(ctx, dates, opts \\ []) do
    periods = Enum.map(dates, fn {label, date} -> {label, nil, date} end)
    data = Enum.map(periods, fn {_label, from, to} -> balances(ctx, from, to) end)
    accounts = accounts(data)

    section = fn type ->
      account_rows(accounts, data, &(&1.type == type))
    end

    earnings = Enum.map(data, &earnings/1)
    assets = section.(:asset)
    liabilities = section.(:liability)
    equity = section.(:equity) ++ [row(["Current earnings" | earnings], depth: 1)]
    width = length(dates) + 1

    rows =
      [heading("Assets")] ++
        assets ++
        [subtotal(sums(assets, "Total assets", width))] ++
        [heading("Liabilities")] ++
        liabilities ++
        [subtotal(sums(liabilities, "Total liabilities", width))] ++
        [heading("Equity")] ++
        equity ++
        [subtotal(sums(equity, "Total equity", width))] ++
        [total(sums(liabilities ++ equity, "Total liabilities and equity", width))]

    columns = [col("Account") | Enum.map(dates, fn {label, _} -> col(label, :money) end)]
    maybe_change(table(columns, rows), opts[:change?])
  end

  # Profit and loss

  def profit_and_loss(ctx), do: profit_and_losses(ctx, [{"Total", ctx.from, ctx.to}])

  def profit_and_loss_by_month(ctx), do: profit_and_losses(ctx, months(ctx.from, ctx.to), true)

  def profit_and_loss_by_quarter(ctx),
    do: profit_and_losses(ctx, quarters(ctx.from, ctx.to), true)

  def profit_and_loss_comparison(ctx) do
    previous = {Date.shift(ctx.from, year: -1), Date.shift(ctx.to, year: -1)}

    profit_and_losses(ctx, [
      {range_label(ctx.from, ctx.to), ctx.from, ctx.to},
      {range_label(elem(previous, 0), elem(previous, 1)), elem(previous, 0), elem(previous, 1)}
    ])
    |> maybe_change(true)
  end

  def profit_and_loss_ytd(ctx) do
    profit_and_losses(ctx, [
      {range_label(ctx.from, ctx.to), ctx.from, ctx.to},
      {"Year to date", Date.new!(ctx.to.year, 1, 1), ctx.to}
    ])
  end

  def profit_and_loss_percent(ctx) do
    report = profit_and_loss(ctx)
    data = balances(ctx, ctx.from, ctx.to)

    income =
      data |> Map.values() |> Enum.filter(&(&1.account.type == :income)) |> Enum.map(& &1.amount)

    income = sum(income)

    rows =
      Enum.map(report.rows, fn
        %{kind: :heading} = row ->
          row

        %{cells: [label, amount]} = row ->
          %{row | cells: [label, amount, percent(amount, income)]}
      end)

    %{report | columns: report.columns ++ [col("% of income", :percent)], rows: rows}
  end

  def profit_and_loss_detail(ctx), do: Ledger.account_detail(ctx, [:income, :expense])

  defp profit_and_losses(ctx, periods, total_column? \\ false) do
    periods =
      if total_column? and length(periods) > 1,
        do: periods ++ [{"Total", ctx.from, ctx.to}],
        else: periods

    data = Enum.map(periods, fn {_label, from, to} -> balances(ctx, from, to) end)
    accounts = accounts(data)
    width = length(periods) + 1

    income = account_rows(accounts, data, &(&1.type == :income))

    cost =
      account_rows(
        accounts,
        data,
        &(&1.type == :expense and &1.system_key in @cost_of_sales_keys)
      )

    expenses =
      account_rows(
        accounts,
        data,
        &(&1.type == :expense and &1.system_key not in @cost_of_sales_keys)
      )

    income_total = sums(income, "Total income", width)
    cost_total = sums(cost, "Total cost of sales", width)
    expense_total = sums(expenses, "Total expenses", width)
    gross = combine(income_total, cost_total, "Gross profit")
    net = combine(gross, expense_total, "Net income")

    rows =
      [heading("Income")] ++
        income ++
        [subtotal(income_total)] ++
        if(cost == [], do: [], else: [heading("Cost of sales")] ++ cost ++ [subtotal(cost_total)]) ++
        [subtotal(gross)] ++
        [heading("Expenses")] ++
        expenses ++
        [subtotal(expense_total)] ++
        [total(net)]

    table([col("Account") | Enum.map(periods, fn {label, _, _} -> col(label, :money) end)], rows)
  end

  # Cash flows (indirect method)

  def cash_flows(ctx) do
    data = balances(ctx, ctx.from, ctx.to)
    rows = Map.values(data) |> Enum.sort_by(& &1.account.code)
    net_income = earnings(data)

    # A rise in an asset uses cash; a rise in a liability or equity brings it in.
    change = fn %{account: account, amount: amount} ->
      if account.type == :asset, do: Decimal.negate(amount), else: amount
    end

    pick = fn filter ->
      for entry <- rows,
          filter.(entry.account),
          value = change.(entry),
          not Decimal.eq?(value, 0),
          do: row([account_label(entry.account), value], depth: 1)
    end

    operating =
      pick.(fn account ->
        account.system_key not in @cash_keys and
          ((account.type == :asset and account.system_key != nil) or account.type == :liability)
      end)

    investing = pick.(&(&1.type == :asset and &1.system_key == nil))
    financing = pick.(&(&1.type == :equity))

    operating_total = sum([net_income | Enum.map(operating, &Enum.at(&1.cells, 1))])
    investing_total = sum(Enum.map(investing, &Enum.at(&1.cells, 1)))
    financing_total = sum(Enum.map(financing, &Enum.at(&1.cells, 1)))
    net_change = sum([operating_total, investing_total, financing_total])

    opening =
      if ctx.from,
        do: cash_balance(ctx, Date.add(ctx.from, -1)),
        else: Decimal.new(0)

    table(
      [col("Activity"), col("Total", :money)],
      [heading("Operating activities"), row(["Net income", net_income], depth: 1)] ++
        operating ++
        [subtotal(["Net cash from operating activities", operating_total])] ++
        [heading("Investing activities")] ++
        investing ++
        [subtotal(["Net cash from investing activities", investing_total])] ++
        [heading("Financing activities")] ++
        financing ++
        [subtotal(["Net cash from financing activities", financing_total])] ++
        [
          subtotal(["Net change in cash", net_change]),
          row(["Cash at beginning of period", opening]),
          total(["Cash at end of period", Decimal.add(opening, net_change)])
        ]
    )
  end

  defp cash_balance(ctx, date) do
    ctx
    |> balances(nil, date)
    |> Map.values()
    |> Enum.filter(&(&1.account.system_key in @cash_keys))
    |> Enum.map(& &1.amount)
    |> sum()
  end

  # Changes in equity

  def changes_in_equity(ctx) do
    opening = balances(ctx, nil, Date.add(ctx.from, -1))
    period = balances(ctx, ctx.from, ctx.to)
    zero = Decimal.new(0)

    equity =
      for {id, entry} <- Map.merge(opening, period),
          entry.account.type == :equity,
          open = get_in(opening, [id, :amount]) || zero,
          move = get_in(period, [id, :amount]) || zero,
          not (Decimal.eq?(open, 0) and Decimal.eq?(move, 0)) do
        {entry.account.code,
         row([account_label(entry.account), open, nil, move, Decimal.add(open, move)],
           link: "/accounting/accounts/#{id}"
         )}
      end
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    earnings_open = earnings(opening)
    profit = earnings(period)

    rows =
      equity ++
        [
          row([
            "Current earnings",
            earnings_open,
            profit,
            nil,
            Decimal.add(earnings_open, profit)
          ])
        ]

    table(
      [
        col("Equity component"),
        col("Opening", :money),
        col("Profit for the period", :money),
        col("Other movements", :money),
        col("Closing", :money)
      ],
      rows ++ [total(totals(rows, 5, [1, 2, 3, 4], "Total equity"))]
    )
  end

  # Business snapshot

  def business_snapshot(ctx) do
    alias Zippiker.Reporting.Reports.Sales

    data = balances(ctx, ctx.from, ctx.to)
    position = balances(ctx, nil, ctx.to) |> Map.values()
    values = Map.values(data)

    income =
      values |> Enum.filter(&(&1.account.type == :income)) |> Enum.map(& &1.amount) |> sum()

    expenses = values |> Enum.filter(&(&1.account.type == :expense))
    expense_total = expenses |> Enum.map(& &1.amount) |> sum()

    top_expenses =
      expenses
      |> Enum.reject(&Decimal.eq?(&1.amount, 0))
      |> Enum.sort_by(& &1.amount, {:desc, Decimal})
      |> Enum.take(5)
      |> Enum.map(
        &row([account_label(&1.account), &1.amount],
          depth: 1,
          link: "/accounting/accounts/#{&1.account.id}"
        )
      )

    top_customers =
      if :sales in (ctx.organization.enabled_modules || []) do
        ctx
        |> Sales.customer_sales()
        |> Enum.take(5)
        |> Enum.map(fn {party, net} -> row([Context.name(party), net], depth: 1) end)
      else
        []
      end

    position_of = fn keys ->
      position |> Enum.filter(&(&1.account.system_key in keys)) |> Enum.map(& &1.amount) |> sum()
    end

    table(
      [col("Item"), col("Amount", :money)],
      [
        heading("Income and expenses"),
        row(["Income", income], depth: 1),
        row(["Expenses", expense_total], depth: 1),
        subtotal(["Net income", Decimal.sub(income, expense_total)]),
        heading("Top customers by sales")
      ] ++
        top_customers ++
        [heading("Top expenses")] ++
        top_expenses ++
        [
          heading("Position on #{format(ctx.to)}"),
          row(["Cash and bank", position_of.(@cash_keys)], depth: 1),
          row(["Owed to you (receivables)", position_of.([:receivable])], depth: 1),
          row(["You owe (payables)", position_of.([:payable])], depth: 1),
          row(["Tax payable", position_of.([:tax_payable])], depth: 1)
        ]
    )
  end

  # Helpers

  @doc "Normal-side balance of every account for a period: `%{id => %{account, amount}}`."
  def balances(ctx, from, to) do
    for row <- Balances.accounts(ctx.tenant, from, to, ctx.branch_id), into: %{} do
      {row.account.id, %{account: row.account, amount: Balances.normal(row)}}
    end
  end

  def account_label(account), do: "#{account.code} · #{account.name}"

  defp accounts(data) do
    data
    |> Enum.flat_map(&Map.values/1)
    |> Enum.map(& &1.account)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.code)
  end

  defp account_rows(accounts, data, filter) do
    zero = Decimal.new(0)

    for account <- accounts,
        filter.(account),
        amounts = Enum.map(data, &(get_in(&1, [account.id, :amount]) || zero)),
        Enum.any?(amounts, &(not Decimal.eq?(&1, 0))) do
      row([account_label(account) | amounts],
        depth: 1,
        link: "/accounting/accounts/#{account.id}"
      )
    end
  end

  defp earnings(data) do
    values = Map.values(data)
    income = values |> Enum.filter(&(&1.account.type == :income)) |> Enum.map(& &1.amount)
    expense = values |> Enum.filter(&(&1.account.type == :expense)) |> Enum.map(& &1.amount)
    Decimal.sub(sum(income), sum(expense))
  end

  defp sums(rows, label, width), do: totals(rows, width, Enum.to_list(1..(width - 1)), label)

  defp combine([_ | a], [_ | b], label) do
    [label | Enum.zip_with(a, b, &Decimal.sub/2)]
  end

  # Adds "Change" and "%" columns comparing the first two amount columns.
  defp maybe_change(report, true) do
    rows =
      Enum.map(report.rows, fn
        %{kind: :heading} = row ->
          row

        %{cells: [label, a, b | rest]} = row ->
          change = Decimal.sub(a, b)
          %{row | cells: [label, a, b | rest] ++ [change, percent(change, Decimal.abs(b))]}
      end)

    %{report | columns: report.columns ++ [col("Change", :money), col("%", :percent)], rows: rows}
  end

  defp maybe_change(report, _), do: report

  defp sum(values), do: Context.sum(values)

  @doc "Months in a range as `{label, first, last}`, clipped to the range (at most 24)."
  def months(from, to) do
    Stream.iterate(Date.beginning_of_month(from), &Date.shift(&1, month: 1))
    |> Enum.take_while(&(Date.compare(&1, to) != :gt))
    |> Enum.take(24)
    |> Enum.map(fn first ->
      {Calendar.strftime(first, "%b %Y"), Enum.max([first, from], Date),
       Enum.min([Date.end_of_month(first), to], Date)}
    end)
  end

  @doc "Quarters in a range as `{label, first, last}`, clipped to the range."
  def quarters(from, to) do
    start = Date.new!(from.year, div(from.month - 1, 3) * 3 + 1, 1)

    Stream.iterate(start, &Date.shift(&1, month: 3))
    |> Enum.take_while(&(Date.compare(&1, to) != :gt))
    |> Enum.take(12)
    |> Enum.map(fn first ->
      last = first |> Date.shift(month: 2) |> Date.end_of_month()

      {"Q#{div(first.month - 1, 3) + 1} #{first.year}", Enum.max([first, from], Date),
       Enum.min([last, to], Date)}
    end)
  end

  defp format(date), do: Calendar.strftime(date, "%b %-d, %Y")
  defp range_label(from, to), do: "#{format(from)} – #{format(to)}"
end
