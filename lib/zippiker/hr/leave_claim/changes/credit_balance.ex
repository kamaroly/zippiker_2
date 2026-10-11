defmodule Zippiker.HR.LeaveClaim.Changes.CreditBalance do
  @moduledoc "An approved claim adds its days to the employee's balance."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, claim ->
      Zippiker.HR.LeaveBalanceEntry
      |> Ash.Changeset.for_create(
        :record,
        %{
          kind: :claim,
          employee_id: claim.employee_id,
          leave_type_id: claim.leave_type_id,
          leave_policy_id: claim.leave_policy_id,
          claim_id: claim.id,
          days: claim.days,
          effective_on: claim.worked_on,
          note: claim.reason
        },
        tenant: changeset.tenant,
        actor: context.actor
      )
      |> Ash.create(authorize?: false)
      |> case do
        {:ok, _entry} -> {:ok, claim}
        error -> error
      end
    end)
  end
end
