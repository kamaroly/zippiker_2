defmodule Zippiker.Accounts.Membership.Changes.AssignDefaultRoles do
  @moduledoc """
  New plain members get the workspace's default roles (seeding the
  built-in roles first if the workspace has none yet).
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Zippiker.Accounts.Role
  alias Zippiker.Accounts.Role.Actions.SeedDefaults

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, membership ->
      if membership.role == :member do
        organization_id = membership.organization_id

        if Ash.exists?(Role, tenant: organization_id, authorize?: false),
          do: SeedDefaults.assign_defaults(organization_id, [membership.id]),
          else: SeedDefaults.seed(organization_id)
      end

      {:ok, membership}
    end)
  end
end
