defmodule Zippiker.Accounts.Role.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounts.Role.{Actions, Changes, Validations}

  actions do
    defaults [:read]

    read :list do
      prepare build(sort: [name: :asc], load: [:members_count])
    end

    create :create do
      primary? true
      accept [:name, :description, :permissions, :default?]
      validate Validations.KnownPermissions
    end

    update :update do
      primary? true
      accept [:name, :description, :permissions, :default?]
      validate Validations.KnownPermissions
    end

    update :reset do
      description "Puts a built-in role's permissions back to the defaults."
      require_atomic? false
      change Changes.ResetPermissions
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      validate Validations.NotBuiltIn
    end

    action :seed_defaults, :integer do
      description """
      Creates the built-in roles a workspace is missing and gives members
      without any role the default ones. Returns how many roles were created.
      """

      argument :organization_id, :uuid, allow_nil?: false
      run Actions.SeedDefaults
    end
  end
end
