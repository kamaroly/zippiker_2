defmodule Zippiker.HR.LeaveRequest.Changes.Decide do
  @moduledoc """
  Approve / reject. Requests in a workflow decide its current step (the
  workflow approves the request once the last step does); requests from
  before workflows are decided directly.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, context) do
    decision = Keyword.fetch!(opts, :decision)

    case changeset.data.approval_request_id do
      nil ->
        Ash.Changeset.force_change_attributes(changeset, %{
          status: if(decision == :approve, do: :approved, else: :rejected),
          decided_at: DateTime.utc_now(),
          decided_by_id: context.actor && context.actor.id
        })

      approval_id ->
        Ash.Changeset.after_action(changeset, fn changeset, request ->
          opts = [tenant: changeset.tenant, actor: context.actor]
          note = Ash.Changeset.get_attribute(changeset, :decision_note)

          with {:ok, approval} <- Zippiker.Workflow.get_approval_request(approval_id, opts),
               {:ok, _approval} <-
                 Zippiker.Workflow.decide_approval(approval, decision, %{comment: note}, opts) do
            {:ok,
             Ash.get!(Zippiker.HR.LeaveRequest, request.id,
               tenant: changeset.tenant,
               authorize?: false
             )}
          end
        end)
    end
  end
end
