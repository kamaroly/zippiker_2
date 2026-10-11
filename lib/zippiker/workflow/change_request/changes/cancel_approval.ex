defmodule Zippiker.Workflow.ChangeRequest.Changes.CancelApproval do
  @moduledoc "Withdraws the pending approval of a cancelled change request."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, request ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      with id when is_binary(id) <- request.approval_request_id,
           {:ok, %{status: :pending} = approval} <-
             Zippiker.Workflow.get_approval_request(id, opts),
           {:ok, _approval} <- Zippiker.Workflow.cancel_approval(approval, opts) do
        {:ok, request}
      else
        {:error, error} -> {:error, error}
        _ -> {:ok, request}
      end
    end)
  end
end
