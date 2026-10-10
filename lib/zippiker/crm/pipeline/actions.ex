defmodule Zippiker.Crm.Pipeline.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [position: :asc, inserted_at: :asc], load: [:stages])
    end

    create :create do
      primary? true
      accept [:name, :position]
    end

    update :update do
      primary? true
      accept [:name, :position]
    end

    action :seed_defaults, :struct do
      description "Creates the default sales pipeline for a new organization, once."
      constraints instance_of: Zippiker.Crm.Pipeline
      run Zippiker.Crm.Pipeline.Actions.SeedDefaults
    end
  end
end
