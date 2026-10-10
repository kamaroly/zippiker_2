defmodule Zippiker.Accounting.Reports.Actions.ProfitAndLoss do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Reports.Balances

  @impl true
  def run(input, _opts, _context) do
    today = Date.utc_today()
    from = input.arguments[:from] || Date.beginning_of_month(today)
    to = input.arguments[:to] || today
    {:ok, report(input.tenant, from, to)}
  end

  def report(tenant, from, to) do
    rows = Balances.accounts(tenant, from, to)
    income = Balances.section(rows, :income)
    expenses = Balances.section(rows, :expense)
    income_total = Balances.total(income)
    expense_total = Balances.total(expenses)

    %{
      from: from,
      to: to,
      income: income,
      expenses: expenses,
      income_total: income_total,
      expense_total: expense_total,
      net: Decimal.sub(income_total, expense_total)
    }
  end
end
