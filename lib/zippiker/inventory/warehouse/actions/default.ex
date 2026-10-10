defmodule Zippiker.Inventory.Warehouse.Actions.Default do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Inventory.Warehouse

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]

    Warehouse
    |> Ash.Query.filter(default? == true)
    |> Ash.read_one(opts)
    |> case do
      {:ok, nil} ->
        Warehouse
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Main warehouse", code: "MAIN", default?: true},
          opts
        )
        |> Ash.create(authorize?: false)

      other ->
        other
    end
  end
end
