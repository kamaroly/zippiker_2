defmodule Zippiker.Accounting.Reports.Balances do
  @moduledoc """
  Per-account debit and credit sums for a date range, computed in the
  database with aggregates. Shared by the report actions.
  """
  require Ash.Query

  alias Zippiker.Accounting.{Account, JournalLine}

  @doc "Every account with `:debits` and `:credits` for lines dated in `from..to` (nil = open)."
  def accounts(tenant, from, to) do
    from = from || ~D[1900-01-01]
    to = to || ~D[9999-12-31]
    lines = JournalLine |> Ash.Query.filter(date >= ^from and date <= ^to)

    Account
    |> Ash.Query.aggregate(:debits, :sum, :lines,
      field: :debit,
      query: lines,
      default: Decimal.new(0)
    )
    |> Ash.Query.aggregate(:credits, :sum, :lines,
      field: :credit,
      query: lines,
      default: Decimal.new(0)
    )
    |> Ash.Query.sort(code: :asc)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(fn account ->
      %{
        account: account,
        debits: account.aggregates.debits || Decimal.new(0),
        credits: account.aggregates.credits || Decimal.new(0)
      }
    end)
  end

  @doc "Balance on the account's normal side (debit for assets and expenses)."
  def normal(%{account: %{type: type}, debits: debits, credits: credits})
      when type in [:asset, :expense],
      do: Decimal.sub(debits, credits)

  def normal(%{debits: debits, credits: credits}), do: Decimal.sub(credits, debits)

  @doc "Rows of a type with a non-zero normal balance, as `%{account, amount}`."
  def section(rows, type) do
    for row <- rows, row.account.type == type, amount = normal(row), not Decimal.eq?(amount, 0) do
      %{account: row.account, amount: amount}
    end
  end

  def total(section), do: Enum.reduce(section, Decimal.new(0), &Decimal.add(&2, &1.amount))
end
