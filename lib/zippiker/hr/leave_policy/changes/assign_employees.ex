defmodule Zippiker.HR.LeavePolicy.Changes.AssignEmployees do
  @moduledoc """
  Makes the chosen employees (and everyone in a department) the people on
  this policy, replacing their previous policy for the same leave type;
  people no longer chosen are taken off it.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Zippiker.HR.{Employee, LeavePolicyAssignment}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, policy ->
      opts = [tenant: changeset.tenant, authorize?: false]
      ids = Ash.Changeset.get_argument(changeset, :employee_ids) || []
      department_id = Ash.Changeset.get_argument(changeset, :department_id)

      department_ids =
        if department_id,
          do:
            Employee
            |> Ash.Query.filter(department_id == ^department_id)
            |> Ash.read!(opts)
            |> Enum.map(& &1.id),
          else: []

      target = Enum.uniq(ids ++ department_ids)

      LeavePolicyAssignment
      |> Ash.Query.filter(leave_policy_id == ^policy.id and employee_id not in ^target)
      |> Ash.bulk_destroy!(:destroy, %{}, opts ++ [strategy: [:stream]])

      Ash.bulk_create!(
        Enum.map(
          target,
          &%{employee_id: &1, leave_policy_id: policy.id, leave_type_id: policy.leave_type_id}
        ),
        LeavePolicyAssignment,
        :assign,
        opts ++ [return_errors?: true, stop_on_error?: true]
      )

      {:ok, policy}
    end)
  end
end
