defmodule Zippiker.Manufacturing.BillOfMaterials.Validations.Producible do
  @moduledoc "The finished product must be a stock-tracked product."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    with id when is_binary(id) <- Ash.Changeset.get_attribute(changeset, :product_id),
         {:ok, %{track_inventory?: true}} <-
           Zippiker.Catalog.get_product(id, tenant: changeset.tenant, authorize?: false) do
      :ok
    else
      _ -> {:error, field: :product_id, message: "choose a stock-tracked product"}
    end
  end
end
