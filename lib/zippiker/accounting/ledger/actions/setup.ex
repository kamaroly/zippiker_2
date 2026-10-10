defmodule Zippiker.Accounting.Ledger.Actions.Setup do
  @moduledoc """
  A small-business chart of accounts. On a workspace that already has
  accounts only the missing system accounts are added: an existing account
  with the default code and type is adopted, otherwise a new one is created.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounting.Account

  @chart [
    {"1000", "Cash", :asset, :cash},
    {"1010", "Bank", :asset, :bank},
    {"1020", "Mobile money", :asset, :mobile_money},
    {"1100", "Accounts receivable", :asset, :receivable},
    {"1200", "Inventory", :asset, :inventory},
    {"1300", "Input tax receivable", :asset, :tax_receivable},
    {"1500", "Equipment", :asset, nil},
    {"2000", "Accounts payable", :liability, :payable},
    {"2100", "Sales tax payable", :liability, :tax_payable},
    {"2150", "Goods received not billed", :liability, :grni},
    {"2200", "Credit card", :liability, nil},
    {"2300", "Employee reimbursements", :liability, :reimbursements},
    {"3000", "Owner's equity", :equity, :equity},
    {"3900", "Retained earnings", :equity, :retained_earnings},
    {"4000", "Sales revenue", :income, :revenue},
    {"4900", "Other income", :income, nil},
    {"5000", "Cost of sales", :expense, :cost_of_sales},
    {"5100", "Inventory adjustments", :expense, :inventory_adjustment},
    {"5200", "Manufacturing overhead applied", :expense, :production_overhead},
    {"6000", "Salaries & wages", :expense, nil},
    {"6100", "Rent & utilities", :expense, nil},
    {"6200", "Software & subscriptions", :expense, nil},
    {"6300", "Marketing", :expense, nil},
    {"6400", "Travel", :expense, nil},
    {"6500", "Bank fees", :expense, nil},
    {"6900", "Other expenses", :expense, :expense}
  ]

  @doc "The default chart: `{code, name, type, system_key}`."
  def chart, do: @chart

  @doc "Every system key automatic postings rely on."
  def system_keys, do: for({_code, _name, _type, key} <- @chart, key, do: key)

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    existing = Ash.read!(Account, opts)
    keys = MapSet.new(existing, & &1.system_key)
    codes = MapSet.new(existing, & &1.code)

    missing =
      Enum.filter(@chart, fn {_code, _name, _type, key} ->
        if existing == [], do: true, else: key != nil and key not in keys
      end)

    {adopt, to_create} =
      Enum.split_with(missing, fn {code, _name, type, _key} ->
        Enum.any?(existing, &(&1.code == code and &1.type == type and is_nil(&1.system_key)))
      end)

    Enum.each(adopt, fn {code, _name, _type, key} ->
      existing
      |> Enum.find(&(&1.code == code))
      |> Ash.Changeset.for_update(:assign_system_key, %{system_key: key}, opts)
      |> Ash.update!(authorize?: false)
    end)

    created =
      Enum.map(to_create, fn {code, name, type, key} ->
        Account
        |> Ash.Changeset.for_create(
          :seed,
          %{code: free_code(code, codes), name: name, type: type, system_key: key},
          opts
        )
        |> Ash.create!(authorize?: false)
      end)

    {:ok, %{created: length(created), total: length(existing) + length(created)}}
  end

  # A renamed chart may already use the default code.
  defp free_code(code, codes) do
    if MapSet.member?(codes, code), do: code <> "-1", else: code
  end
end
