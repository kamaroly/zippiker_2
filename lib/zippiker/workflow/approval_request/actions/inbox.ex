defmodule Zippiker.Workflow.ApprovalRequest.Actions.Inbox do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Workflow.{ApprovalRequest, Approvers}

  @impl true
  def run(input, _opts, context) do
    actor_id = context.actor && context.actor.id

    requests =
      ApprovalRequest
      |> Ash.Query.filter(status == :pending)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.load([:steps, :requested_by])
      |> Ash.read!(tenant: input.tenant, authorize?: false)

    {:ok,
     Enum.filter(requests, fn request ->
       case Enum.find(request.steps, &(&1.status == :pending)) do
         nil -> false
         step -> actor_id in Approvers.for_step(step, request, input.tenant)
       end
     end)}
  end
end
