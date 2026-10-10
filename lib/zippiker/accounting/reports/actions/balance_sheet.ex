defmodule Zippiker.Accounting.Reports.Actions.BalanceSheet do
  @moduledoc """
  Until a year-end close exists, all profit to date shows as "Current
  earnings" inside equity, which is what makes the sheet balance.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Reports.Balances

  @impl true
  def run(input, _opts, _context) do
    as_of = input.arguments[:as_of] || Date.utc_today()
    rows = Balances.accounts(input.tenant, nil, as_of)

    assets = Balances.section(rows, :asset)
    liabilities = Balances.section(rows, :liability)
    equity = Balances.section(rows, :equity)

    earnings =
      Decimal.sub(
        Balances.total(Balances.section(rows, :income)),
        Balances.total(Balances.section(rows, :expense))
      )

    assets_total = Balances.total(assets)
    liabilities_total = Balances.total(liabilities)
    equity_total = Decimal.add(Balances.total(equity), earnings)

    {:ok,
     %{
       as_of: as_of,
       assets: assets,
       liabilities: liabilities,
       equity: equity,
       earnings: earnings,
       assets_total: assets_total,
       liabilities_total: liabilities_total,
       equity_total: equity_total,
       balanced?: Decimal.eq?(assets_total, Decimal.add(liabilities_total, equity_total))
     }}
  end
end
