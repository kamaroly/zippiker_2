defmodule Zippiker.HR.Automation.Actions.ReviewOverdue do
  @moduledoc """
  Pending requests older than their policy's `review_threshold_days` get
  the policy's `overdue_action` (approve or reject). Requests that can no
  longer be approved (e.g. the balance ran out) stay pending for a person.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.HR.{Entitlement, LeaveRequest}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    now = input.arguments[:now] || DateTime.utc_now()

    decided =
      LeaveRequest
      |> Ash.Query.filter(status == :pending)
      |> Ash.read!(opts)
      |> Enum.count(fn request ->
        policy = Entitlement.policy_for(request.employee_id, request.leave_type_id, opts)

        with %{overdue_action: action, review_threshold_days: days}
             when action != :none and is_integer(days) <- policy,
             true <- DateTime.diff(now, request.inserted_at, :day) >= days,
             {:ok, _request} <-
               request
               |> Ash.Changeset.for_update(:auto_decide, %{decision: action}, opts)
               |> Ash.update(authorize?: false) do
          true
        else
          _ -> false
        end
      end)

    {:ok, %{decided: decided}}
  end
end
