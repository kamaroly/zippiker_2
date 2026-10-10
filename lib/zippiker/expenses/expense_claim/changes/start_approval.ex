defmodule Zippiker.Expenses.ExpenseClaim.Changes.StartApproval do
  @moduledoc """
  Starts the claim's approval (`Zippiker.Workflow`). When every step is
  skipped (nobody but the claimant could approve) the workflow approves it at
  once, so the claim is reloaded before it's returned.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, claim ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      params = %{
        document_type: :expense_claim,
        document_id: claim.id,
        document_label: String.slice("#{claim.number} · #{claim.title}", 0, 120),
        amount: Money.to_decimal(claim.total || Money.new!(claim.currency, 0))
      }

      with {:ok, request} <- Zippiker.Workflow.start_approval(params, opts) do
        Zippiker.Expenses.ExpenseClaim
        |> Ash.get!(claim.id, opts)
        |> Ash.Changeset.for_update(:link_approval, %{approval_request_id: request.id}, opts)
        |> Ash.update(authorize?: false)
      end
    end)
  end
end
