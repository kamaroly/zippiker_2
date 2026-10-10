defmodule Zippiker.Inventory.StockOperation.Changes.PrepareMovements do
  @moduledoc """
  Turns the `lines` argument (product_id, quantity, optional unit_cost) into
  signed movements:

    * receipts bring stock in at the given cost (default: the product's cost price)
    * deliveries take stock out at the current average cost
    * adjustments are signed: in at the given/average cost, out at average cost
    * lines marked `signed: true` (reversals) are taken as they are

  Only stock-tracked products can move. Sets `total_value`.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    lines = Ash.Changeset.get_argument(changeset, :lines) || []
    ids = lines |> Enum.map(&get(&1, :product_id)) |> Enum.uniq()

    products =
      Zippiker.Catalog.Product
      |> Ash.Query.filter(id in ^ids)
      |> Ash.read!(tenant: changeset.tenant, authorize?: false)
      |> Map.new(&{&1.id, &1})

    kind = Ash.Changeset.get_attribute(changeset, :kind)
    date = Ash.Changeset.get_attribute(changeset, :date) || Date.utc_today()
    warehouse_id = Ash.Changeset.get_attribute(changeset, :warehouse_id)

    with :ok <- check(lines, products) do
      movements =
        lines
        |> Enum.with_index()
        |> Enum.map(fn {line, index} ->
          product = Map.fetch!(products, get(line, :product_id))
          {quantity, unit_cost} = signed(kind, line, product)

          %{
            product_id: product.id,
            warehouse_id: warehouse_id,
            date: date,
            position: index,
            quantity: quantity,
            unit_cost: unit_cost
          }
        end)

      value =
        movements
        |> Enum.reduce(Decimal.new(0), fn movement, sum ->
          Decimal.add(sum, Decimal.abs(Decimal.mult(movement.quantity, movement.unit_cost)))
        end)
        |> Decimal.round(2)

      changeset
      |> Ash.Changeset.force_change_attributes(%{date: date, total_value: value})
      |> Ash.Changeset.force_set_argument(:lines, movements)
    else
      {:error, message} -> Ash.Changeset.add_error(changeset, field: :lines, message: message)
    end
  end

  defp check([], _products), do: {:error, "there is nothing to move"}

  defp check(lines, products) do
    cond do
      Enum.any?(lines, &(not Map.has_key?(products, get(&1, :product_id)))) ->
        {:error, "unknown product"}

      Enum.any?(products, fn {_id, product} -> not product.track_inventory? end) ->
        {:error, "only stock-tracked products can be moved"}

      Enum.any?(lines, &Decimal.eq?(decimal(get(&1, :quantity)), 0)) ->
        {:error, "quantities can't be zero"}

      true ->
        :ok
    end
  end

  defp signed(_kind, %{signed: true} = line, _product),
    do: {decimal(line.quantity), decimal(line.unit_cost)}

  defp signed(:receipt, line, product),
    do: {Decimal.abs(decimal(get(line, :quantity))), cost(line, product.cost_price)}

  defp signed(:delivery, line, product),
    do: {Decimal.negate(Decimal.abs(decimal(get(line, :quantity)))), product.average_cost}

  defp signed(:adjustment, line, product) do
    quantity = decimal(get(line, :quantity))

    if Decimal.gt?(quantity, 0) do
      fallback =
        if Decimal.gt?(product.average_cost, 0),
          do: product.average_cost,
          else: product.cost_price

      {quantity, cost(line, fallback)}
    else
      {quantity, product.average_cost}
    end
  end

  defp cost(line, fallback) do
    case get(line, :unit_cost) do
      nil -> fallback
      "" -> fallback
      value -> decimal(value)
    end
  end

  defp get(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp decimal(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp decimal(_value), do: Decimal.new(0)
end
