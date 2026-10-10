defmodule Zippiker.Inventory.Reports.Actions.Levels do
  @moduledoc """
  Quantity per stock-tracked product, computed in the database. With
  `warehouse_id`, only that warehouse's movements count.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Catalog.Product
  alias Zippiker.Inventory.StockMovement

  @impl true
  def run(input, _opts, _context) do
    movements =
      case input.arguments[:warehouse_id] do
        nil -> Ash.Query.new(StockMovement)
        id -> Ash.Query.filter(StockMovement, warehouse_id == ^id)
      end

    products =
      Product
      |> Ash.Query.filter(track_inventory? == true)
      |> search(input.arguments[:query])
      |> Ash.Query.aggregate(:quantity, :sum, :stock_movements,
        field: :quantity,
        query: movements,
        default: Decimal.new(0)
      )
      |> Ash.Query.load([:on_hand, :low_stock?])
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: input.tenant, authorize?: false)

    {:ok,
     Enum.map(products, fn product ->
       quantity = product.aggregates.quantity || Decimal.new(0)

       %{
         product: product,
         quantity: quantity,
         value: Decimal.round(Decimal.mult(quantity, product.average_cost), 2),
         low_stock?: product.low_stock?
       }
     end)}
  end

  defp search(query, text) when is_binary(text) and text != "" do
    pattern = "%" <> String.replace(String.trim(text), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(name, ^pattern) or ilike(sku, ^pattern))
  end

  defp search(query, _text), do: query
end
