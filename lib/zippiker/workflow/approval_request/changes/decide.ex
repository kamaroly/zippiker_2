defmodule Zippiker.Workflow.ApprovalRequest.Changes.Decide do
  @moduledoc "Records the actor's decision on the current step; a rejection rejects the request."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    decision = Ash.Changeset.get_argument(changeset, :decision)

    changeset =
      if decision == :reject,
        do:
          Ash.Changeset.force_change_attributes(changeset, %{
            status: :rejected,
            decided_at: DateTime.utc_now()
          }),
        else: changeset

    Ash.Changeset.after_action(changeset, fn changeset, request ->
      opts = [tenant: changeset.tenant, authorize?: false]
      request = Ash.load!(request, :steps, opts)
      step = Enum.find(request.steps, &(&1.status == :pending))

      step
      |> Ash.Changeset.for_update(
        :set_status,
        %{
          status: if(decision == :approve, do: :approved, else: :rejected),
          decided_at: DateTime.utc_now(),
          decided_by_id: context.actor.id,
          comment: Ash.Changeset.get_argument(changeset, :comment)
        },
        opts
      )
      |> Ash.update!(authorize?: false)

      {:ok, request}
    end)
  end
end
