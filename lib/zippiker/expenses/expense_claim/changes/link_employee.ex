defmodule Zippiker.Expenses.ExpenseClaim.Changes.LinkEmployee do
  @moduledoc "Links the claim to the claimant's employee record, if they have one."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      claimant_id = Ash.Changeset.get_attribute(changeset, :claimant_id)

      employee =
        claimant_id &&
          Zippiker.HR.Employee
          |> Ash.Query.filter(user_id == ^claimant_id)
          |> Ash.Query.limit(1)
          |> Ash.read_one!(tenant: changeset.tenant, authorize?: false)

      if employee,
        do: Ash.Changeset.force_change_attribute(changeset, :employee_id, employee.id),
        else: changeset
    end)
  end
end
