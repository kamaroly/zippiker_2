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
      prepare build(load: [:user], sort: [inserted_at: :asc])
    end
  end
end
