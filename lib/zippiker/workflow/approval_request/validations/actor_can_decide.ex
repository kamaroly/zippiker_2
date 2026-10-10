defmodule Zippiker.Workflow.ApprovalRequest.Validations.ActorCanDecide do
  @moduledoc "Only an approver of the current step may decide (never the initiator)."
  use Ash.Resource.Validation

  alias Zippiker.Workflow.Approvers

  @impl true
  def validate(changeset, _opts, %{actor: %{id: actor_id}}) do
    request = Ash.load!(changeset.data, :steps, tenant: changeset.tenant, authorize?: false)

    case Enum.find(request.steps, &(&1.status == :pending)) do
      nil ->
        {:error, message: "nothing is waiting for a decision"}

      step ->
        if actor_id in Approvers.for_step(step, request, changeset.tenant),
          do: :ok,
          else: {:error, message: "you're not an approver for this step"}
    end
  end

  def validate(_changeset, _opts, _context), do: {:error, message: "sign in to decide"}
end
