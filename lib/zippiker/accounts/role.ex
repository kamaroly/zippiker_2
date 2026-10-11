defmodule Zippiker.Accounts.Role do
  @moduledoc """
  A named set of permissions in one workspace (e.g. "Sales representative").
  Members get roles; what a member may do is the union of their roles'
  permissions. Owners and admins can always do everything.

  Every workspace starts with the default roles from
  `Zippiker.Accounts.Permissions.default_roles/0` (they carry a `key`);
  roles marked `default?` are given to new members.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.Role.Attributes,
      Zippiker.Accounts.Role.Relationships,
      Zippiker.Accounts.Role.Actions,
      Zippiker.Accounts.Role.Policies
    ]

  postgres do
    table "roles"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
    end
  end

  # `global?` so a member's roles load alongside their membership (which
  # isn't tenant scoped); writes still always carry the workspace.
  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  identities do
    identity :unique_name, [:organization_id, :name]
  end
end
