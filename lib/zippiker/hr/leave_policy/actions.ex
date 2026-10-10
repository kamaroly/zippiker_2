defmodule Zippiker.HR.LeavePolicy.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.LeavePolicy.Changes

  actions do
    defaults [:read]

    read :list do
      prepare build(
                sort: [default?: :desc, name: :asc],
                load: [:employees_count, rules: [:leave_type]]
              )
    end

    create :create do
      primary? true
      accept [:name, :description, :default?]
      change Changes.SingleDefault
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :description, :default?]
      change Changes.SingleDefault
    end

    update :set_rules do
      description "Replaces the entitlements: `[%{leave_type_id, days_per_year, carry_over_days}]`."
      require_atomic? false
      argument :rules, {:array, :map}, allow_nil?: false
      change Changes.CleanRules
      change manage_relationship(:rules, type: :direct_control, on_match: :update)
    end

    update :assign do
      description "Puts employees on this policy, by id and/or a whole department."
      require_atomic? false
      argument :employee_ids, {:array, :uuid}, default: []
      argument :department_id, :uuid
      change Changes.AssignEmployees
    end

    destroy :destroy do
      primary? true
      description "Employees on it fall back to the default policy."
    end
  end
end
