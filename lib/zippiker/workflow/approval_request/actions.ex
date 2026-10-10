defmodule Zippiker.Workflow.ApprovalRequest.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Workflow.ApprovalRequest.{Changes, Validations}

  actions do
    defaults [:read]

    create :start do
      description "Starts approval for a document with the matching workflow."
      accept [:document_type, :document_id, :document_label, :amount]
      argument :steps, {:array, :map}, default: []
      change relate_actor(:requested_by)
      change Changes.PickWorkflow
      change manage_relationship(:steps, type: :create)
      change Changes.Advance
    end

    update :decide do
      require_atomic? false
      argument :decision, :atom, allow_nil?: false, constraints: [one_of: [:approve, :reject]]
      argument :comment, :string, constraints: [max_length: 1_000]
      validate attribute_equals(:status, :pending), message: "this approval is already closed"
      validate Validations.ActorCanDecide
      change Changes.Decide
      change Changes.Advance
    end

    update :cancel do
      description "The initiator withdrew the document."
      require_atomic? false
      validate attribute_equals(:status, :pending), message: "this approval is already closed"
      change set_attribute(:status, :cancelled)
      change set_attribute(:current_position, nil)
    end

    update :set_state do
      accept [:status, :current_position, :decided_at]
    end

    action :inbox, {:array, :struct} do
      description "Pending requests the actor can decide now."
      constraints items: [instance_of: Zippiker.Workflow.ApprovalRequest]
      run Zippiker.Workflow.ApprovalRequest.Actions.Inbox
    end
  end
end
