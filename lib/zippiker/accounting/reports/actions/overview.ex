defmodule Zippiker.Accounting.Reports.Actions.Overview do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Reports.Actions.ProfitAndLoss
  alias Zippiker.Accounting.Reports.Balances

  @money_keys [:cash, :bank, :mobile_money]

  @impl true
  def run(input, _opts, _context) do
    today = Date.utc_today()
    rows = Balances.accounts(input.tenant, nil, today)

    balance = fn keys ->
      sum(for row <- rows, row.account.system_key in keys, do: Balances.normal(row))
    end

    trend =
      for offset <- 5..0//-1 do
        month = today |> Date.beginning_of_month() |> Date.shift(month: -offset)
        report = ProfitAndLoss.report(input.tenant, month, Date.end_of_month(month))
        %{month: month, income: report.income_total, expenses: report.expense_total}
      end

    this_month = List.last(trend)

    {:ok,
     %{
       set_up?: rows != [],
       cash: balance.(@money_keys),
       receivable: balance.([:receivable]),
       tax_payable: balance.([:tax_payable]),
       payable: balance.([:payable]),
       inventory: balance.([:inventory]),
       income_this_month: this_month.income,
       expenses_this_month: this_month.expenses,
       net_this_month: Decimal.sub(this_month.income, this_month.expenses),
       trend: trend
     }}
  end

  defp sum(amounts), do: Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2)
end
