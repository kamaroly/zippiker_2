defmodule Zippiker.Sales.Changes.DefaultOwner do
  @moduledoc "New documents belong to their creator unless an owner is chosen."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: %{id: actor_id}}) do
    if Ash.Changeset.get_attribute(changeset, :owner_id),
      do: changeset,
      else: Ash.Changeset.force_change_attribute(changeset, :owner_id, actor_id)
  end

  def change(changeset, _opts, _context), do: changeset
end
