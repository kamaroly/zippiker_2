defmodule Zippiker.Manufacturing.ProductionOrder.Validations.BomMatchesProduct do
  @moduledoc "The order needs a bill of materials, and it must be for the order's product."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_attribute(changeset, :product_id)

    case Ash.Changeset.get_attribute(changeset, :bom_id) do
      nil ->
        {:error, field: :bom_id, message: "this product has no bill of materials yet"}

      bom_id ->
        case Zippiker.Manufacturing.get_bom(bom_id, tenant: changeset.tenant, authorize?: false) do
          {:ok, %{product_id: ^product_id}} -> :ok
          _ -> {:error, field: :bom_id, message: "choose a bill of materials for this product"}
        end
    end
  end
end
