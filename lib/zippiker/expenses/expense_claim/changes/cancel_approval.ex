defmodule Zippiker.Expenses.ExpenseClaim.Changes.CancelApproval do
  @moduledoc "Withdraws the claim's approval request if it's still waiting for decisions."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, claim ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      with id when is_binary(id) <- claim.approval_request_id,
           {:ok, %{status: :pending} = request} <-
             Zippiker.Workflow.get_approval_request(id, opts),
           {:ok, _request} <- Zippiker.Workflow.cancel_approval(request, opts) do
        {:ok, claim}
      else
        {:error, error} -> {:error, error}
        _nothing_pending -> {:ok, claim}
      end
    end)
  end
end
