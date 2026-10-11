defmodule Zippiker.HR.LeaveBalanceEntry.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :for_employee do
      argument :employee_id, :uuid, allow_nil?: false
      filter expr(employee_id == ^arg(:employee_id))

      prepare build(
                sort: [effective_on: :desc, inserted_at: :desc],
                load: [:leave_type, :created_by]
              )
    end

    create :adjust do
      description "An admin adds (or takes away) days by hand."
      accept [:employee_id, :leave_type_id, :days, :effective_on, :note]
      change set_attribute(:kind, :adjustment)
      change relate_actor(:created_by)

      validate Zippiker.HR.LeaveBalanceEntry.Validations.NonZeroDays
    end

    create :record do
      description "Accruals and claims, written by the system."

      accept [
        :employee_id,
        :leave_type_id,
        :leave_policy_id,
        :claim_id,
        :kind,
        :days,
        :effective_on,
        :period,
        :note
      ]
    end
  end
end
