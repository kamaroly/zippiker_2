defmodule Zippiker.Inventory.StockOperation.Changes.UpdateAverageCost do
  @moduledoc """
  Re-weights each product's average cost after its movements are saved:
  `(before × old average + Σ quantity × unit cost) / after`. Goods leaving at
  the average cost leave it unchanged; incoming goods move it. When stock
  drops to zero or below, the last average is kept.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, operation ->
      opts = [tenant: changeset.tenant, authorize?: false]
      operation = Ash.load!(operation, [movements: [product: [:on_hand]]], opts)

      operation.movements
      |> Enum.group_by(& &1.product_id)
      |> Enum.each(fn {_id, [%{product: product} | _] = movements} ->
        moved = sum(movements, & &1.quantity)
        value = sum(movements, &Decimal.mult(&1.quantity, &1.unit_cost))
        after_qty = product.on_hand
        before_qty = Decimal.sub(after_qty, moved)

        if Decimal.gt?(after_qty, 0) do
          before_value =
            if Decimal.gt?(before_qty, 0),
              do: Decimal.mult(before_qty, product.average_cost),
              else: Decimal.new(0)

          base_qty = if Decimal.gt?(before_qty, 0), do: after_qty, else: moved

          average =
            if Decimal.gt?(base_qty, 0),
              do: before_value |> Decimal.add(value) |> Decimal.div(base_qty) |> Decimal.round(6),
              else: product.average_cost

          average = if Decimal.lt?(average, 0), do: Decimal.new(0), else: average

          product
          |> Ash.Changeset.for_update(:set_average_cost, %{average_cost: average}, opts)
          |> Ash.update!(authorize?: false)
        end
      end)

      {:ok, operation}
    end)
  end

  defp sum(list, fun), do: Enum.reduce(list, Decimal.new(0), &Decimal.add(&2, fun.(&1)))
end
