defmodule Zippiker.Catalog.TaxRate.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    destroy :destroy do
      # Atomic unless maker-checker holds the change (see MakerChecker).
      require_atomic? false
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :tax_rates}
      primary? true
    end

    read :list do
      prepare build(sort: [default?: :desc, rate: :asc])
    end

    create :create do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :tax_rates}
      primary? true
      accept [:name, :rate, :default?]
    end

    update :update do
      # Atomic unless maker-checker holds the change (see MakerChecker).
      require_atomic? false
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :tax_rates}
      primary? true
      accept [:name, :rate, :default?]
    end
  end
end
