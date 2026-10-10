defmodule Zippiker.HR.Department.Validations.NotOwnParent do
  @moduledoc "A department can't sit under itself."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :parent_id) == changeset.data.id,
      do: {:error, field: :parent_id, message: "can't be its own parent"},
      else: :ok
  end
end
