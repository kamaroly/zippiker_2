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
      change Zippiker.Accounts.Organization.Changes.CreateDefaultLegalEntity
      change Zippiker.Accounts.Organization.Changes.StartSubscription
    end

    update :update do
      primary? true
      accept [:name, :currency]
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
