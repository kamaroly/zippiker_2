defmodule Zippiker.Inventory.StockOperation.Changes.SetDefaults do
  @moduledoc "Default warehouse and legal entity when none are given."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    opts = [tenant: changeset.tenant, authorize?: false]

    changeset
    |> default(:warehouse_id, fn -> Zippiker.Inventory.default_warehouse!(opts).id end)
    |> default(:legal_entity_id, fn -> Zippiker.Accounts.default_legal_entity!(opts).id end)
  end

  defp default(changeset, field, fun) do
    if Ash.Changeset.get_attribute(changeset, field),
      do: changeset,
      else: Ash.Changeset.force_change_attribute(changeset, field, fun.())
  end
end
