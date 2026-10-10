defmodule Zippiker.Manufacturing.Costing do
  @moduledoc """
  What a production run needs and costs, from a bill of materials (loaded
  with `components: [product: [:on_hand]]` and `operations: [:work_center]`).
  Quantities scale with `quantity / bom.quantity`; components are valued at
  their average cost (cost price until stock has a cost) and operations at
  their work center's hourly rate.
  """

  @doc "One row per component: required quantity, on hand, shortage and cost."
  def requirements(bom, quantity) do
    factor = factor(bom, quantity)

    Enum.map(bom.components, fn component ->
      required =
        component.quantity |> Decimal.mult(factor) |> Decimal.round(4) |> Decimal.normalize()

      on_hand = component.product.on_hand || Decimal.new(0)
      shortage = Decimal.sub(required, on_hand)
      unit_cost = unit_cost(component.product)

      %{
        product: component.product,
        required: required,
        on_hand: on_hand,
        shortage: if(Decimal.gt?(shortage, 0), do: shortage, else: Decimal.new(0)),
        unit_cost: unit_cost,
        cost: required |> Decimal.mult(unit_cost) |> Decimal.round(2)
      }
    end)
  end

  @doc "One row per operation: minutes for this quantity and labour/overhead cost."
  def operations(bom, quantity) do
    factor = factor(bom, quantity)

    Enum.map(bom.operations, fn operation ->
      minutes = operation.minutes |> Decimal.mult(factor) |> Decimal.round(1)

      %{
        operation: operation,
        minutes: minutes,
        cost:
          minutes
          |> Decimal.div(60)
          |> Decimal.mult(operation.work_center.hourly_rate)
          |> Decimal.round(2)
      }
    end)
  end

  @doc "Material, labour/overhead and total cost of making `quantity`, plus the unit cost."
  def estimate(bom, quantity) do
    materials = sum(requirements(bom, quantity), & &1.cost)
    labour = sum(operations(bom, quantity), & &1.cost)
    total = Decimal.add(materials, labour)

    %{
      materials: materials,
      labour: labour,
      total: total,
      unit_cost:
        if(Decimal.gt?(quantity, 0),
          do: total |> Decimal.div(quantity) |> Decimal.round(6),
          else: Decimal.new(0)
        )
    }
  end

  @doc "Components that don't have enough stock for `quantity`."
  def shortages(bom, quantity),
    do: Enum.filter(requirements(bom, quantity), &Decimal.gt?(&1.shortage, 0))

  def unit_cost(product) do
    if Decimal.gt?(product.average_cost, 0), do: product.average_cost, else: product.cost_price
  end

  defp factor(bom, quantity), do: Decimal.div(decimal(quantity), bom.quantity)

  defp sum(rows, fun), do: Enum.reduce(rows, Decimal.new(0), &Decimal.add(&2, fun.(&1)))

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_binary(value), do: Decimal.new(value)
end
