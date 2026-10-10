defmodule Zippiker.Manufacturing.BillOfMaterials.Validations.HasComponents do
  @moduledoc """
  Components (when given) must be at least one stock-tracked product other
  than the finished product, each with a positive quantity.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :components) do
      {:ok, components} when is_list(components) -> check(changeset, components)
      _ -> :ok
    end
  end

  defp check(_changeset, []),
    do: {:error, field: :components, message: "add at least one component"}

  defp check(changeset, components) do
    product_id = Ash.Changeset.get_attribute(changeset, :product_id)
    ids = Enum.map(components, &get(&1, :product_id))

    tracked =
      Zippiker.Catalog.Product
      |> Ash.Query.filter(id in ^Enum.reject(ids, &is_nil/1) and track_inventory? == true)
      |> Ash.read!(tenant: changeset.tenant, authorize?: false)
      |> MapSet.new(& &1.id)

    cond do
      product_id in ids ->
        {:error, field: :components, message: "a product can't be its own component"}

      Enum.any?(ids, &(not MapSet.member?(tracked, &1))) ->
        {:error, field: :components, message: "components must be stock-tracked products"}

      Enum.any?(components, &(not positive?(get(&1, :quantity)))) ->
        {:error, field: :components, message: "component quantities must be above zero"}

      true ->
        :ok
    end
  end

  defp positive?(%Decimal{} = value), do: Decimal.gt?(value, 0)
  defp positive?(value) when is_number(value), do: value > 0

  defp positive?(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, ""} -> Decimal.gt?(decimal, 0)
      _ -> false
    end
  end

  defp positive?(_value), do: false

  defp get(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
end
