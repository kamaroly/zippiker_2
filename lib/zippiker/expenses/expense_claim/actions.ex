defmodule Zippiker.Expenses.ExpenseClaim.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Expenses.ExpenseClaim.{Changes, Validations}
  alias Zippiker.Sales.Changes, as: SalesChanges
  alias Zippiker.Sales.Validations.InStatus

  @statuses [:draft, :submitted, :approved, :rejected, :reimbursed, :cancelled]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: @statuses]
      argument :mine?, :boolean, default: false, description: "Only the actor's own claims"
      argument :claimant_id, :uuid
      prepare Zippiker.Expenses.ExpenseClaim.Preparations.Search
      prepare build(sort: [inserted_at: :desc], load: [:claimant, employee: [:name]])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept [:title, :notes, :legal_entity_id]
      argument :items, {:array, :map}, default: []

      change relate_actor(:claimant)
      change SalesChanges.SetLegalEntity
      change Changes.LinkEmployee
      change {SalesChanges.AssignNumber, document_type: :expense_claim, prefix: "EXP"}
      change manage_relationship(:items, type: :direct_control)
      change Changes.ComputeTotal
    end

    update :update do
      primary? true
      accept [:title, :notes]
      require_atomic? false
      argument :items, {:array, :map}

      validate {InStatus,
                statuses: [:draft, :rejected],
                message: "only draft or rejected claims can be edited"}

      change manage_relationship(:items, type: :direct_control)
      change Changes.ComputeTotal
    end

    update :set_total do
      accept [:total]
    end

    update :submit do
      description "Sends the claim for approval through the workspace's expense workflow."
      require_atomic? false
      validate {InStatus, statuses: [:draft, :rejected]}
      validate Validations.HasItems
      change set_attribute(:status, :submitted)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
      change set_attribute(:rejected_at, nil)
      change Changes.StartApproval
    end

    update :link_approval do
      accept [:approval_request_id]
    end

    update :mark_approved do
      require_atomic? false
      validate {InStatus, statuses: [:submitted]}
      change set_attribute(:status, :approved)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change {Changes.PostToLedger, event: :approved}
    end

    update :mark_rejected do
      require_atomic? false
      validate {InStatus, statuses: [:submitted]}
      change set_attribute(:status, :rejected)
      change set_attribute(:rejected_at, &DateTime.utc_now/0)
    end

    update :reimburse do
      description "Records that the claimant was paid back."
      require_atomic? false
      accept [:reimbursed_on, :reimbursed_from, :reimbursement_reference]
      validate {InStatus, statuses: [:approved], message: "only approved claims can be paid"}
      validate present([:reimbursed_on, :reimbursed_from])
      change set_attribute(:status, :reimbursed)
      change {Changes.PostToLedger, event: :reimbursed}
    end

    update :cancel do
      require_atomic? false

      validate {InStatus,
                statuses: [:draft, :submitted, :rejected],
                message: "approved claims can't be cancelled"}

      change set_attribute(:status, :cancelled)
      change Changes.CancelApproval
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      validate {InStatus, statuses: [:draft], message: "only drafts can be deleted"}
    end

    action :apply_approval, :struct do
      description "Called by the workflow when the claim's approval finishes."
      constraints instance_of: Zippiker.Expenses.ExpenseClaim
      argument :claim_id, :uuid, allow_nil?: false

      argument :outcome, :atom,
        allow_nil?: false,
        constraints: [one_of: [:approved, :rejected]]

      run Zippiker.Expenses.ExpenseClaim.Actions.ApplyApproval
    end
  end
end
