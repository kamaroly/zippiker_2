defmodule Zippiker.HR.ChecklistTemplate.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:name, :kind, :description, :default?, :active?]

  actions do
    defaults [:read, :destroy]

    read :list do
      argument :kind, :atom, constraints: [one_of: [:onboarding, :offboarding]]
      argument :active_only?, :boolean, default: false
      filter expr(is_nil(^arg(:kind)) or kind == ^arg(:kind))
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [kind: :asc, default?: :desc, name: :asc], load: [tasks: [:user]])
    end

    create :create do
      primary? true
      accept @fields
      argument :tasks, {:array, :map}, default: []
      change Zippiker.HR.ChecklistTemplate.Changes.SingleDefault
      change manage_relationship(:tasks, type: :direct_control)
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      argument :tasks, {:array, :map}
      change Zippiker.HR.ChecklistTemplate.Changes.SingleDefault
      change manage_relationship(:tasks, type: :direct_control)
    end
  end
end
