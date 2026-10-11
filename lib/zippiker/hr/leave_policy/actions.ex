defmodule Zippiker.HR.LeavePolicy.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.LeavePolicy.{Changes, Validations}

  @fields [
    :name,
    :description,
    :default?,
    :effective_date,
    :category,
    :days_per_year,
    :carry_over_days,
    :accrual_days,
    :accrual_frequency,
    :accrual_cap,
    :review_threshold_days,
    :overdue_action,
    :requires_attachment?,
    :count_weekends_and_holidays?,
    :allow_backdated?,
    :claimable?,
    :active?
  ]

  actions do
    defaults [:read]

    read :list do
      argument :leave_type_id, :uuid
      filter expr(is_nil(^arg(:leave_type_id)) or leave_type_id == ^arg(:leave_type_id))

      prepare build(
                sort: [default?: :desc, name: :asc],
                load: [:employees_count, :leave_type]
              )
    end

    create :create do
      primary? true
      accept [:leave_type_id | @fields]
      validate Validations.CategorySettings
      change Changes.SingleDefault
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      validate Validations.CategorySettings
      change Changes.SingleDefault
    end

    update :assign do
      description """
      Sets who's on this policy: exactly `employee_ids`, plus everyone in
      `department_id`. They leave any other policy for the same leave type.
      """

      require_atomic? false
      argument :employee_ids, {:array, :uuid}, default: []
      argument :department_id, :uuid
      change Changes.AssignEmployees
    end

    destroy :destroy do
      primary? true
      description "People on it fall back to the leave type's default policy."
    end
  end
end
