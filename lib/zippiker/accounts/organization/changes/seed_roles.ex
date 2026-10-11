defmodule Zippiker.Accounts.Organization.Changes.SeedRoles do
  @moduledoc "Every new workspace starts with the built-in roles."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, organization ->
      Zippiker.Accounts.Role.Actions.SeedDefaults.seed(organization.id)
      {:ok, organization}
    end)
  end
end
