defmodule Zippiker.Accounting.Account.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :list do
      argument :type, :atom,
        constraints: [one_of: [:asset, :liability, :equity, :income, :expense]]

      argument :active_only?, :boolean, default: false

      filter expr(
               (is_nil(^arg(:type)) or type == ^arg(:type)) and
                 (^arg(:active_only?) == false or active? == true)
             )

      prepare build(sort: [code: :asc], load: [:balance, :used?])
    end

    create :create do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :accounts}
      primary? true
      accept [:code, :name, :type, :description]
    end

    create :seed do
      description "Used when setting up the default chart (can set `system_key`)."
      accept [:code, :name, :type, :description, :system_key]
    end

    update :assign_system_key do
      description "Used by setup to adopt an existing account for automatic postings."
      accept [:system_key]
    end

    update :update do
      # Atomic unless maker-checker holds the change (see MakerChecker).
      require_atomic? false
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :accounts}
      primary? true
      accept [:code, :name, :description, :active?]
    end

    destroy :destroy do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :accounts}
      primary? true
      require_atomic? false
      validate Zippiker.Accounting.Account.Validations.Deletable
    end
  end
end
