defmodule Zippiker.Reporting.Reports.Ledger do
  @moduledoc """
  Reports for the accountant, straight from journal entries and lines:
  general ledger, journal, trial balances, transaction lists and checks.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Accounting.{Account, JournalEntry, JournalLine}
  alias Zippiker.Accounting.Reports.Balances
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.Financial

  # Account detail (general ledger and friends)

  def general_ledger(ctx),
    do: account_detail(ctx, [:asset, :liability, :equity, :income, :expense], opening?: true)

  def transactions_by_account(ctx),
    do: account_detail(ctx, [:asset, :liability, :equity, :income, :expense])

  @doc """
  Postings per account in the period with a running balance on the
  account's normal side; `opening?: true` starts from the balance before
  the period.
  """
  def account_detail(ctx, types, opts \\ []) do
    lines =
      JournalLine
      |> Ash.Query.filter(date >= ^ctx.from and date <= ^ctx.to and account.type in ^types)
      |> branch(ctx)
      |> Ash.Query.load([:account, :party, :journal_entry])
      |> Ash.Query.sort(date: :asc, inserted_at: :asc)
      |> Context.read(ctx)

    opening =
      if opts[:opening?] do
        for row <- Balances.accounts(ctx.tenant, nil, Date.add(ctx.from, -1), ctx.branch_id),
            row.account.type in types,
            into: %{},
            do: {row.account.id, {row.account, Balances.normal(row)}}
      else
        %{}
      end

    zero = Decimal.new(0)
    by_account = Enum.group_by(lines, & &1.account_id)

    accounts =
      (Enum.map(lines, & &1.account) ++ Enum.map(Map.values(opening), &elem(&1, 0)))
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.code)

    blocks =
      Enum.flat_map(accounts, fn account ->
        account_lines = Map.get(by_account, account.id, [])
        {_account, start} = Map.get(opening, account.id, {account, zero})

        if account_lines == [] and Decimal.eq?(start, 0) do
          []
        else
          {rows, closing} =
            Enum.map_reduce(account_lines, start, fn line, balance ->
              balance = Decimal.add(balance, signed(account, line))

              {row(
                 [
                   line.date,
                   line.journal_entry.number,
                   source_label(line.journal_entry),
                   Context.name(line.party, ""),
                   line.description || line.journal_entry.memo,
                   positive(line.debit),
                   positive(line.credit),
                   balance
                 ],
                 depth: 1,
                 link: "/accounting/journal/#{line.journal_entry_id}"
               ), balance}
            end)

          opening_row =
            if opts[:opening?],
              do: [row([nil, nil, nil, nil, "Opening balance", nil, nil, start], depth: 1)],
              else: []

          [heading(Financial.account_label(account), link: "/accounting/accounts/#{account.id}")] ++
            opening_row ++
            rows ++
            [
              subtotal([
                "Total for #{account.name}",
                nil,
                nil,
                nil,
                nil,
                sum_column(rows, 5),
                sum_column(rows, 6),
                closing
              ])
            ]
        end
      end)

    data = Enum.filter(blocks, &(&1.kind == :row and Enum.at(&1.cells, 5) != nil))

    footer =
      if blocks == [],
        do: [],
        else: [
          total(["Total", nil, nil, nil, nil, sum_column(data, 5), sum_column(data, 6), nil])
        ]

    table(detail_columns(), blocks ++ footer)
  end

  defp detail_columns do
    [
      col("Date", :date),
      col("Number"),
      col("Type"),
      col("Name"),
      col("Description"),
      col("Debit", :money),
      col("Credit", :money),
      col("Balance", :money)
    ]
  end

  def general_ledger_list(ctx) do
    opening = Balances.accounts(ctx.tenant, nil, Date.add(ctx.from, -1), ctx.branch_id)
    period = Balances.accounts(ctx.tenant, ctx.from, ctx.to, ctx.branch_id)
    opening = Map.new(opening, &{&1.account.id, &1})

    rows =
      for row <- period,
          open = Balances.normal(opening[row.account.id]),
          not (Decimal.eq?(open, 0) and Decimal.eq?(row.debits, 0) and
                 Decimal.eq?(row.credits, 0)) do
        closing = Decimal.add(open, Balances.normal(row))

        row(
          [
            Financial.account_label(row.account),
            Context.humanize(row.account.type),
            open,
            row.debits,
            row.credits,
            closing
          ],
          link: "/accounting/accounts/#{row.account.id}"
        )
      end

    table(
      [
        col("Account"),
        col("Type"),
        col("Opening", :money),
        col("Debits", :money),
        col("Credits", :money),
        col("Closing", :money)
      ],
      rows ++ footer(rows, 6, [3, 4])
    )
  end

  # Journal and transaction lists

  def journal(ctx) do
    entries = entries(ctx)

    rows =
      Enum.flat_map(entries, fn entry ->
        entry.lines
        |> Enum.sort_by(& &1.position)
        |> Enum.with_index()
        |> Enum.map(fn {line, index} ->
          first? = index == 0

          row(
            [
              if(first?, do: entry.date),
              if(first?, do: entry.number),
              Financial.account_label(line.account),
              Context.name(line.party, ""),
              line.description || if(first?, do: entry.memo),
              positive(line.debit),
              positive(line.credit)
            ],
            link: "/accounting/journal/#{entry.id}"
          )
        end)
      end)

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Account"),
        col("Name"),
        col("Memo"),
        col("Debit", :money),
        col("Credit", :money)
      ],
      rows ++ footer(rows, 7, [5, 6])
    )
  end

  def recent_transactions(ctx) do
    entries = ctx |> entries() |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    rows =
      Enum.map(entries, fn entry ->
        row(
          [
            entry.date,
            source_label(entry),
            entry.number,
            entry_party(entry),
            entry.memo,
            entry.total,
            Context.user_name(entry.posted_by)
          ],
          link: "/accounting/journal/#{entry.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col("Name"),
        col("Memo"),
        col("Amount", :money),
        col("Posted by")
      ],
      rows
    )
  end

  def transactions_by_date(ctx) do
    rows =
      Enum.map(entries(ctx), fn entry ->
        accounts = entry.lines |> Enum.map(& &1.account) |> Enum.uniq_by(& &1.id)

        account =
          case accounts do
            [one] -> Financial.account_label(one)
            [a, b] -> "#{a.name} / #{b.name}"
            _ -> "Split (#{length(accounts)} accounts)"
          end

        row(
          [
            entry.date,
            source_label(entry),
            entry.number,
            entry_party(entry),
            entry.memo,
            account,
            entry.total
          ],
          link: "/accounting/journal/#{entry.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col("Name"),
        col("Memo"),
        col("Account"),
        col("Amount", :money)
      ],
      rows ++ footer(rows, 7, [6])
    )
  end

  def transactions_with_splits(ctx) do
    rows =
      Enum.flat_map(entries(ctx), fn entry ->
        lines =
          entry.lines
          |> Enum.sort_by(& &1.position)
          |> Enum.map(fn line ->
            row(
              [
                nil,
                Financial.account_label(line.account),
                Context.name(line.party, ""),
                line.description,
                positive(line.debit),
                positive(line.credit)
              ],
              depth: 1
            )
          end)

        [
          heading(
            "#{Context.format_date(entry.date)} · #{entry.number} · #{source_label(entry)}" <>
              if(entry.memo, do: " · #{entry.memo}", else: ""),
            link: "/accounting/journal/#{entry.id}"
          )
        ] ++ lines
      end)

    table(
      [
        col("Date", :date),
        col("Account"),
        col("Name"),
        col("Description"),
        col("Debit", :money),
        col("Credit", :money)
      ],
      rows ++ footer(rows, 6, [4, 5])
    )
  end

  def invalid_transactions(ctx) do
    rows =
      for entry <- entries(ctx),
          debits = Context.sum(Enum.map(entry.lines, & &1.debit)),
          credits = Context.sum(Enum.map(entry.lines, & &1.credit)),
          problems = problems(entry, debits, credits),
          problems != [] do
        row(
          [
            entry.date,
            entry.number,
            source_label(entry),
            entry.memo,
            debits,
            credits,
            Enum.join(problems, "; ")
          ],
          link: "/accounting/journal/#{entry.id}"
        )
      end

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Type"),
        col("Memo"),
        col("Debits", :money),
        col("Credits", :money),
        col("Problem")
      ],
      rows,
      note: "Entries are checked for balance, line count, one-sided lines and inactive accounts."
    )
  end

  defp problems(entry, debits, credits) do
    [
      not Decimal.eq?(debits, credits) && "debits and credits differ",
      length(entry.lines) < 2 && "fewer than two lines",
      Enum.any?(entry.lines, &(positive?(&1.debit) and positive?(&1.credit))) &&
        "a line has both a debit and a credit",
      Enum.any?(entry.lines, &(not positive?(&1.debit) and not positive?(&1.credit))) &&
        "a line has no amount",
      Enum.any?(entry.lines, &(not &1.account.active?)) && "uses an inactive account",
      not Decimal.eq?(Context.amount(entry.total), debits) && "total doesn't match the lines"
    ]
    |> Enum.filter(& &1)
  end

  # Balances

  def trial_balance(ctx) do
    zero = Decimal.new(0)

    rows =
      for row <- Balances.accounts(ctx.tenant, nil, ctx.to, ctx.branch_id),
          net = Decimal.sub(row.debits, row.credits),
          not Decimal.eq?(net, 0) do
        row(
          [
            Financial.account_label(row.account),
            if(Decimal.gt?(net, 0), do: net, else: zero),
            if(Decimal.lt?(net, 0), do: Decimal.negate(net), else: zero)
          ],
          link: "/accounting/accounts/#{row.account.id}"
        )
      end

    table(
      [col("Account"), col("Debit", :money), col("Credit", :money)],
      rows ++ footer(rows, 3, [1, 2])
    )
  end

  def adjusted_trial_balance(ctx) do
    unadjusted = sums(ctx, &Ash.Query.filter(&1, journal_entry.source != :manual))

    adjustments =
      ctx
      |> sums(&Ash.Query.filter(&1, journal_entry.source == :manual))
      |> Map.new(fn {account, net} -> {account.id, net} end)

    rows =
      for {account, before} <- unadjusted,
          adjust = adjustments[account.id] || Decimal.new(0),
          adjusted = Decimal.add(before, adjust),
          not (Decimal.eq?(before, 0) and Decimal.eq?(adjust, 0)) do
        row(
          [Financial.account_label(account)] ++
            split(before) ++ split(adjust) ++ split(adjusted),
          link: "/accounting/accounts/#{account.id}"
        )
      end

    table(
      [
        col("Account"),
        col("Unadjusted debit", :money),
        col("Unadjusted credit", :money),
        col("Adjustment debit", :money),
        col("Adjustment credit", :money),
        col("Adjusted debit", :money),
        col("Adjusted credit", :money)
      ],
      rows ++ footer(rows, 7, [1, 2, 3, 4, 5, 6]),
      note: "Adjustments are manual journal entries; everything else is unadjusted."
    )
  end

  # `{account, net debit}` for every account up to the as-of date, counting
  # only journal lines that pass `filter`.
  defp sums(ctx, filter) do
    lines =
      JournalLine
      |> Ash.Query.filter(date <= ^ctx.to)
      |> filter.()
      |> branch(ctx)

    Account
    |> Ash.Query.aggregate(:debits, :sum, :lines, field: :debit, query: lines, default: 0)
    |> Ash.Query.aggregate(:credits, :sum, :lines, field: :credit, query: lines, default: 0)
    |> Ash.Query.sort(code: :asc)
    |> Context.read(ctx)
    |> Enum.map(fn account ->
      {account,
       Decimal.sub(
         Context.amount(account.aggregates.debits),
         Context.amount(account.aggregates.credits)
       )}
    end)
  end

  defp split(net) do
    zero = Decimal.new(0)

    if Decimal.gt?(net, 0),
      do: [net, zero],
      else: [zero, Decimal.abs(net)]
  end

  def account_list(ctx) do
    balances = Balances.accounts(ctx.tenant, nil, ctx.to, ctx.branch_id)

    rows =
      Enum.map(balances, fn row ->
        row(
          [
            row.account.code,
            row.account.name,
            Context.humanize(row.account.type),
            if(row.account.system_key, do: Context.humanize(row.account.system_key), else: ""),
            if(row.account.active?, do: "Active", else: "Inactive"),
            Balances.normal(row)
          ],
          link: "/accounting/accounts/#{row.account.id}"
        )
      end)

    table(
      [
        col("Code"),
        col("Account"),
        col("Type"),
        col("Used for"),
        col("Status"),
        col("Balance", :money)
      ],
      rows
    )
  end

  # Helpers

  defp entries(ctx) do
    JournalEntry
    |> Ash.Query.filter(date >= ^ctx.from and date <= ^ctx.to)
    |> branch(ctx)
    |> Ash.Query.load([:posted_by, lines: [:account, :party]])
    |> Ash.Query.sort(date: :asc, number: :asc)
    |> Context.read(ctx)
  end

  defp branch(query, %{branch_id: nil}), do: query

  defp branch(%Ash.Query{resource: JournalLine} = query, %{branch_id: id}),
    do: Ash.Query.filter(query, journal_entry.branch_id == ^id)

  defp branch(query, ctx), do: Context.branch(query, ctx)

  defp entry_party(entry) do
    entry.lines |> Enum.find_value(& &1.party) |> Context.name("")
  end

  @doc "A journal entry's type, e.g. \"Invoice\" or \"Journal entry\"."
  def source_label(%{source: :manual}), do: "Journal entry"
  def source_label(%{source: source}), do: Context.humanize(source)

  defp signed(%{type: type}, line) when type in [:asset, :expense],
    do: Decimal.sub(Context.amount(line.debit), Context.amount(line.credit))

  defp signed(_account, line),
    do: Decimal.sub(Context.amount(line.credit), Context.amount(line.debit))

  defp positive(value), do: if(positive?(value), do: value)
  defp positive?(nil), do: false
  defp positive?(value), do: Decimal.gt?(value, 0)

  defp footer([], _width, _indexes), do: []
  defp footer(rows, width, indexes), do: [total(totals(rows, width, indexes, "Total"))]
end
