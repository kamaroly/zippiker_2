defmodule Zippiker.Accounting.Reports.Actions.TrialBalance do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Reports.Balances

  @impl true
  def run(input, _opts, _context) do
    as_of = input.arguments[:as_of] || Date.utc_today()
    zero = Decimal.new(0)

    rows =
      for row <- Balances.accounts(input.tenant, nil, as_of),
          net = Decimal.sub(row.debits, row.credits),
          not Decimal.eq?(net, 0) do
        %{
          account: row.account,
          debit: if(Decimal.gt?(net, 0), do: net, else: zero),
          credit: if(Decimal.lt?(net, 0), do: Decimal.negate(net), else: zero)
        }
      end

    {:ok,
     %{
       as_of: as_of,
       rows: rows,
       debit: Enum.reduce(rows, zero, &Decimal.add(&2, &1.debit)),
       credit: Enum.reduce(rows, zero, &Decimal.add(&2, &1.credit))
     }}
  end
end
