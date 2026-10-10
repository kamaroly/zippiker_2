defmodule Zippiker.Crm.Task.Changes.DefaultAssignee do
  @moduledoc "Assigns new tasks to their creator unless someone else is chosen."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: %{id: actor_id}}) do
    if Ash.Changeset.get_attribute(changeset, :assignee_id),
      do: changeset,
      else: Ash.Changeset.force_change_attribute(changeset, :assignee_id, actor_id)
  end

  def change(changeset, _opts, _context), do: changeset
end
