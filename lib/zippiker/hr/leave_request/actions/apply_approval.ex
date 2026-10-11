defmodule Zippiker.HR.LeaveRequest.Actions.ApplyApproval do
  @moduledoc "Approves or rejects a pending request when its workflow finishes."
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, actor: context.actor, authorize?: false]
    request = Ash.get!(Zippiker.HR.LeaveRequest, input.arguments.request_id, opts)

    if request.status == :pending do
      request
      |> Ash.Changeset.for_update(:mark_decided, %{outcome: input.arguments.outcome}, opts)
      |> Ash.update(authorize?: false)
    else
      {:ok, request}
    end
  end
end
