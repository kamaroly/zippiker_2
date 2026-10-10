defmodule Zippiker.Inventory.Reports.Actions.Summary do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    products =
      Zippiker.Catalog.Product
      |> Ash.Query.filter(track_inventory? == true and active? == true)
      |> Ash.Query.load([:on_hand, :stock_value, :low_stock?])
      |> Ash.read!(tenant: input.tenant, authorize?: false)

    {:ok,
     %{
       tracked: length(products),
       value: Enum.reduce(products, Decimal.new(0), &Decimal.add(&2, &1.stock_value || 0)),
       low_stock: Enum.count(products, & &1.low_stock?),
       negative: Enum.count(products, &Decimal.lt?(&1.on_hand, 0))
     }}
  end
end
