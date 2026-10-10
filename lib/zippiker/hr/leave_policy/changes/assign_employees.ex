defmodule Zippiker.HR.LeavePolicy.Changes.AssignEmployees do
  @moduledoc "Sets `leave_policy_id` on the chosen employees and/or everyone in a department."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, policy ->
      ids = Ash.Changeset.get_argument(changeset, :employee_ids) || []
      department_id = Ash.Changeset.get_argument(changeset, :department_id)

      query =
        if department_id,
          do:
            Ash.Query.filter(Zippiker.HR.Employee, id in ^ids or department_id == ^department_id),
          else: Ash.Query.filter(Zippiker.HR.Employee, id in ^ids)

      query
      |> Ash.bulk_update!(:set_leave_policy, %{leave_policy_id: policy.id},
        tenant: changeset.tenant,
        authorize?: false,
        strategy: [:stream]
      )

      {:ok, policy}
    end)
  end
end
