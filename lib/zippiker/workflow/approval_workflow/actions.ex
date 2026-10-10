defmodule Zippiker.Workflow.ApprovalWorkflow.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :list do
      argument :document_type, :atom, constraints: [one_of: [:expense_claim]]
      filter expr(is_nil(^arg(:document_type)) or document_type == ^arg(:document_type))
      prepare build(sort: [min_amount: :asc, name: :asc], load: [steps: [:user, :group]])
    end

    create :create do
      primary? true
      accept [:name, :document_type, :min_amount, :active?]
      argument :steps, {:array, :map}, default: []
      change Zippiker.Workflow.ApprovalWorkflow.Changes.NumberSteps
      change manage_relationship(:steps, type: :direct_control)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :min_amount, :active?]
      argument :steps, {:array, :map}
      change Zippiker.Workflow.ApprovalWorkflow.Changes.NumberSteps
      change manage_relationship(:steps, type: :direct_control)
    end
  end
end
