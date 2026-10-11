defmodule Zippiker.Accounts.Organization.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :currency, :domain]
      # Filled in by AssignDomain (and the test tenant pool) just before insert.
      allow_nil_input [:domain]
      change Zippiker.Accounts.Organization.Changes.AssignDomain
      change Zippiker.Accounts.Organization.Changes.CreateTenant
      change Zippiker.Accounts.Organization.Changes.AddOwnerMembership
      change Zippiker.Accounts.Organization.Changes.SeedRoles
      change Zippiker.Accounts.Organization.Changes.CreateDefaultLegalEntity
      change Zippiker.Accounts.Organization.Changes.StartSubscription
    end

    create :platform_create do
      description """
      A super admin opens a workspace for someone: the owner is the user with
      `owner_email`, or, if they have no account yet, whoever accepts the
      invitation sent to that address.
      """

      accept [:name, :currency, :domain]
      allow_nil_input [:domain]
      argument :owner_email, :ci_string, allow_nil?: false
      change Zippiker.Accounts.Organization.Changes.AssignDomain
      change Zippiker.Accounts.Organization.Changes.CreateTenant
      change Zippiker.Accounts.Organization.Changes.SeedRoles
      change Zippiker.Accounts.Organization.Changes.CreateDefaultLegalEntity
      change Zippiker.Accounts.Organization.Changes.StartSubscription
      change Zippiker.Accounts.Organization.Changes.AssignOwner
    end

    update :update do
      primary? true
      accept [:name, :currency]
    end

    update :set_multi_branch do
      description "Global setting: whether the business works with several branches."
      accept [:multi_branch?]
    end

    update :set_maker_checker do
      description "Global setting: which changes need a checker's approval."
      accept [:maker_checker?, :maker_checker_scopes]
    end

    update :set_plan_limits do
      description "Modules and seat limit, set by the platform (super admins and billing)."
      accept [:enabled_modules, :seat_limit]
    end

    read :platform_search do
      description "Every workspace on the platform, for super admins."
      argument :query, :string
      prepare Zippiker.Accounts.Organization.Preparations.PlatformSearch
      prepare build(sort: [inserted_at: :desc], load: [:members_count])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end
  end
end
