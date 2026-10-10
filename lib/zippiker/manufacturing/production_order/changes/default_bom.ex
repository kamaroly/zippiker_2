defmodule Zippiker.Manufacturing.ProductionOrder.Changes.DefaultBom do
  @moduledoc "Uses the product's most recent active bill of materials when none is chosen."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_attribute(changeset, :product_id)

    if Ash.Changeset.get_attribute(changeset, :bom_id) || is_nil(product_id) do
      changeset
    else
      Zippiker.Manufacturing.BillOfMaterials
      |> Ash.Query.filter(product_id == ^product_id and active? == true)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(tenant: changeset.tenant, authorize?: false)
      |> case do
        nil -> changeset
        bom -> Ash.Changeset.force_change_attribute(changeset, :bom_id, bom.id)
      end
    end
  end
end
