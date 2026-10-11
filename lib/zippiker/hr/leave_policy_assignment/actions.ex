defmodule Zippiker.HR.LeavePolicyAssignment.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :assign do
      primary? true
      accept [:employee_id, :leave_policy_id, :leave_type_id]
      upsert? true
      upsert_identity :one_per_type
      upsert_fields [:leave_policy_id]
    end
  end
end
