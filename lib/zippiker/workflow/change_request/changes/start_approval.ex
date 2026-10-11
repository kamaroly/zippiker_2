defmodule Zippiker.Workflow.ChangeRequest.Changes.StartApproval do
  @moduledoc "Sends the change request through the workflow engine (`:change_request`)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, request ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      params = %{
        document_type: :change_request,
        document_id: request.id,
        document_label:
          String.slice(
            "#{request.number} · #{Zippiker.Workflow.MakerChecker.scope_label(request.scope)} · #{request.record_label}",
            0,
            120
          ),
        amount: 0
      }

      with {:ok, approval} <- Zippiker.Workflow.start_approval(params, opts) do
        Zippiker.Workflow.ChangeRequest
        |> Ash.get!(request.id, opts)
        |> Ash.Changeset.for_update(:link_approval, %{approval_request_id: approval.id}, opts)
        |> Ash.update(authorize?: false)
      end
    end)
  end
end
