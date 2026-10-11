defmodule Zippiker.Accounts.Role.Changes.ResetPermissions do
  @moduledoc "Restores a built-in role's description and permissions from the catalog."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Zippiker.Accounts.Permissions.default_role(changeset.data.key) do
      nil ->
        Ash.Changeset.add_error(changeset, message: "only built-in roles can be reset")

      role ->
        changeset
        |> Ash.Changeset.force_change_attribute(:permissions, role.permissions)
        |> Ash.Changeset.force_change_attribute(:description, role.description)
    end
  end
end
