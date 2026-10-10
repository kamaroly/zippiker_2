defmodule Zippiker.Expenses.ExpenseClaim.Actions.ApplyApproval do
  @moduledoc "Moves a submitted claim to approved or rejected when its workflow finishes."
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, actor: context.actor, authorize?: false]
    claim = Ash.get!(Zippiker.Expenses.ExpenseClaim, input.arguments.claim_id, opts)

    action =
      case input.arguments.outcome do
        :approved -> :mark_approved
        :rejected -> :mark_rejected
      end

    if claim.status == :submitted do
      claim
      |> Ash.Changeset.for_update(action, %{}, opts)
      |> Ash.update(authorize?: false)
    else
      {:ok, claim}
    end
  end
end
