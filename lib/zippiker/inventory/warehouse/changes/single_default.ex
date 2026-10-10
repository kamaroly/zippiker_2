defmodule Zippiker.Inventory.Warehouse.Changes.SingleDefault do
  @moduledoc "Making a warehouse the default takes the flag away from the previous one."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :default?) and
         Ash.Changeset.changing_attribute?(changeset, :default?) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        Zippiker.Inventory.Warehouse
        |> Ash.Query.filter(default? == true)
        |> Ash.bulk_update!(:update, %{default?: false},
          tenant: changeset.tenant,
          authorize?: false,
          strategy: [:stream]
        )

        changeset
      end)
    else
      changeset
    end
  end
end
