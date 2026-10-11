defmodule Zippiker.HR.LeaveClaim.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.LeaveClaim.{Changes, Preparations}
  alias Zippiker.HR.LeaveRequest.Changes, as: RequestChanges
  alias Zippiker.HR.LeaveRequest.Validations, as: RequestValidations
  alias Zippiker.Sales.Validations.InStatus

  actions do
    defaults [:read]

    read :search do
      argument :status, :atom, constraints: [one_of: [:pending, :approved, :rejected, :cancelled]]
      argument :mine?, :boolean, default: false
      argument :to_decide?, :boolean, default: false
      prepare Preparations.Search

      prepare build(
                sort: [inserted_at: :desc],
                load: [:leave_type, :decided_by, employee: [:name, :manager]]
              )

      pagination offset?: true, countable: true, default_limit: 50, required?: false
    end

    create :create do
      primary? true
      accept [:employee_id, :leave_type_id, :days, :worked_on, :reason]
      change RequestChanges.DefaultEmployee
      validate RequestValidations.EmployeeIsActive
      change Changes.ClaimablePolicy
    end

    update :approve do
      require_atomic? false
      accept [:decision_note]
      validate {InStatus, statuses: [:pending]}
      change set_attribute(:status, :approved)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
      change relate_actor(:decided_by)
      change Changes.CreditBalance
    end

    update :reject do
      require_atomic? false
      accept [:decision_note]
      validate {InStatus, statuses: [:pending]}
      change set_attribute(:status, :rejected)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
      change relate_actor(:decided_by)
    end

    update :cancel do
      require_atomic? false
      validate {InStatus, statuses: [:pending], message: "only pending claims can be withdrawn"}
      change set_attribute(:status, :cancelled)
    end
  end
end
