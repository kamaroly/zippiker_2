defmodule Zippiker.Accounting.Ledger.SystemAccounts do
  @moduledoc "Looks up the accounts postings use by `system_key`, setting up the chart if needed."

  require Ash.Query

  alias Zippiker.Accounting.Account

  @doc "Returns `%{system_key => account_id}` for the tenant."
  def fetch(tenant) do
    opts = [tenant: tenant, authorize?: false]

    keys = by_key(opts)

    if Enum.all?(Zippiker.Accounting.Ledger.Actions.Setup.system_keys(), &Map.has_key?(keys, &1)) do
      keys
    else
      Zippiker.Accounting.setup_books!(opts)
      by_key(opts)
    end
  end

  defp by_key(opts) do
    Account
    |> Ash.Query.filter(not is_nil(system_key))
    |> Ash.read!(opts)
    |> Map.new(&{&1.system_key, &1.id})
  end

  @doc "The money account a payment method lands in."
  def for_method(keys, :cash), do: keys.cash
  def for_method(keys, :mobile_money), do: keys.mobile_money
  def for_method(keys, _method), do: keys.bank
end
