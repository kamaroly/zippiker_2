defmodule Zippiker.HR.LeaveRequest.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.LeaveRequest.{Changes, Validations}
  alias Zippiker.Sales.Validations.InStatus

  actions do
    defaults [:read]

    read :search do
      argument :status, :atom, constraints: [one_of: [:pending, :approved, :rejected, :cancelled]]
      argument :employee_id, :uuid
      argument :mine?, :boolean, default: false, description: "Only the actor's own requests"

      argument :to_decide?, :boolean,
        default: false,
        description: "Pending requests from people who report to the actor"

      argument :from, :date, description: "Overlapping this period"
      argument :to, :date
      prepare Zippiker.HR.LeaveRequest.Preparations.Search

      prepare build(
                sort: [start_date: :desc],
                load: [:leave_type, :decided_by, employee: [:name, :manager]]
              )

      pagination offset?: true, countable: true, default_limit: 50, required?: false
    end

    create :create do
      primary? true

      accept [
        :employee_id,
        :leave_type_id,
        :start_date,
        :end_date,
        :reason,
        :attachment_name,
        :attachment_path
      ]

      change Changes.DefaultEmployee
      change Changes.CountDays
      validate Validations.DatesInOrder
      validate Validations.EmployeeIsActive
      validate Validations.NoOverlap
      validate Validations.PolicyRules
      validate Validations.WithinAllowance
      change Changes.AutoApprove
    end

    update :approve do
      require_atomic? false
      accept [:decision_note]
      validate {InStatus, statuses: [:pending]}
      validate Validations.WithinAllowance
      change set_attribute(:status, :approved)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
      change relate_actor(:decided_by)
    end

    update :reject do
      require_atomic? false
      accept [:decision_note]
      validate {InStatus, statuses: [:pending]}
      change set_attribute(:status, :rejected)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
      change relate_actor(:decided_by)
    end

    update :auto_decide do
      description "Applies the policy's overdue action to a request nobody reviewed in time."
      require_atomic? false
      argument :decision, :atom, allow_nil?: false, constraints: [one_of: [:approve, :reject]]
      validate {InStatus, statuses: [:pending]}
      change Changes.AutoDecide
    end

    update :cancel do
      require_atomic? false
      validate {InStatus, statuses: [:pending, :approved], message: "already closed"}
      change set_attribute(:status, :cancelled)
    end
  end
end
