defmodule Zippiker.Catalog.Product.Validations.TrackOnlyGoods do
  @moduledoc "Only goods can have their stock tracked; services are never on a shelf."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :track_inventory?) and
         Ash.Changeset.get_attribute(changeset, :kind) != :goods do
      {:error, field: :track_inventory?, message: "only goods can be stocked"}
    else
      :ok
    end
  end
end
