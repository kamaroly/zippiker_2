defmodule Zippiker.Accounts.Membership.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
      validate Zippiker.Accounts.Membership.Validations.NotOwner
    end

    create :create do
      primary? true
      accept [:user_id, :organization_id, :role]
      change Zippiker.Accounts.Membership.Changes.AssignDefaultRoles
    end

    update :set_roles do
      description "Replaces the member's roles (roles of this workspace only)."
      require_atomic? false
      argument :role_ids, {:array, :uuid}, allow_nil?: false
      validate Zippiker.Accounts.Membership.Validations.RolesInWorkspace
      # Authorized as a whole by the membership policies (team.manage).
      change manage_relationship(:role_ids, :roles, type: :append_and_remove, authorize?: false)
    end

    update :update_role do
      accept [:role]
      require_atomic? false
      validate Zippiker.Accounts.Membership.Validations.NotOwner
      validate attribute_in(:role, [:admin, :member])
    end

    read :mine do
      filter expr(user_id == ^actor(:id))
      prepare build(load: [:organization], sort: [inserted_at: :asc])
    end

    read :for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
      prepare build(load: [:user, :roles], sort: [inserted_at: :asc])
    end
  end
end
