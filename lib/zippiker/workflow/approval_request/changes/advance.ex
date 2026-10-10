defmodule Zippiker.Workflow.ApprovalRequest.Changes.Advance do
  @moduledoc """
  Moves a pending request to its next step: the first waiting step with
  someone to ask becomes pending; steps with nobody to ask are skipped. When
  no step is left the request is approved. Finished requests notify their
  document (`Zippiker.Workflow.Callbacks`).
  """
  use Ash.Resource.Change

  alias Zippiker.Workflow.{Approvers, Callbacks}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, request ->
      opts = [tenant: changeset.tenant, authorize?: false]
      request = Ash.load!(request, :steps, opts ++ [reuse_values?: false])

      request =
        if request.status == :pending and not Enum.any?(request.steps, &(&1.status == :pending)),
          do: advance(request, request.steps, changeset.tenant, opts),
          else: request

      if request.status in [:approved, :rejected] do
        with {:ok, _document} <-
               Callbacks.finished(request, opts ++ [actor: context.actor]),
             do: {:ok, request}
      else
        {:ok, request}
      end
    end)
  end

  defp advance(request, steps, tenant, opts) do
    case Enum.find(steps, &(&1.status == :waiting)) do
      nil ->
        set_state(
          request,
          %{status: :approved, current_position: nil, decided_at: DateTime.utc_now()},
          opts
        )

      step ->
        if Approvers.for_step(step, request, tenant) == [] do
          set_step(step, :skipped, opts)

          advance(
            request,
            Enum.map(steps, &if(&1.id == step.id, do: %{&1 | status: :skipped}, else: &1)),
            tenant,
            opts
          )
        else
          set_step(step, :pending, opts)
          set_state(request, %{current_position: step.position}, opts)
        end
    end
  end

  defp set_step(step, status, opts) do
    step
    |> Ash.Changeset.for_update(:set_status, %{status: status}, opts)
    |> Ash.update!(authorize?: false)
  end

  defp set_state(request, params, opts) do
    request
    |> Ash.Changeset.for_update(:set_state, params, opts)
    |> Ash.update!(authorize?: false)
    |> Ash.load!(:steps, opts ++ [reuse_values?: false])
  end
end
