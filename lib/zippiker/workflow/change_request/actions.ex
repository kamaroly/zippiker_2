defmodule Zippiker.Workflow.ChangeRequest.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Changes, as: SalesChanges
  alias Zippiker.Sales.Validations.InStatus
  alias Zippiker.Workflow.ChangeRequest.Changes

  actions do
    defaults [:read]

    read :search do
      argument :status, :atom,
        constraints: [one_of: [:pending, :applied, :rejected, :cancelled, :failed]]

      argument :mine?, :boolean, default: false
      filter expr(is_nil(^arg(:status)) or status == ^arg(:status))
      filter expr(^arg(:mine?) == false or requested_by_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc], load: [:requested_by, :approval_request])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :request do
      description "Holds a change for approval (from `Workflow.Changes.MakerChecker`)."

      accept [
        :scope,
        :resource,
        :action,
        :action_type,
        :record_id,
        :record_label,
        :params,
        :changes
      ]

      change relate_actor(:requested_by)
      change SalesChanges.SetLegalEntity
      change {SalesChanges.AssignNumber, document_type: :change_request, prefix: "CR"}
      change Changes.StartApproval
    end

    update :link_approval do
      accept [:approval_request_id]
    end

    update :set_outcome do
      accept [:status, :error, :applied_at]
    end

    update :cancel do
      description "The maker withdraws the change."
      require_atomic? false
      validate {InStatus, statuses: [:pending]}
      change set_attribute(:status, :cancelled)
      change Changes.CancelApproval
    end

    action :apply_approval, :struct do
      description "Called by the workflow: applies an approved change, or records the rejection."
      constraints instance_of: Zippiker.Workflow.ChangeRequest
      argument :change_request_id, :uuid, allow_nil?: false

      argument :outcome, :atom,
        allow_nil?: false,
        constraints: [one_of: [:approved, :rejected]]

      run Zippiker.Workflow.ChangeRequest.Actions.ApplyApproval
    end
  end
end
