defmodule Zippiker.Workflow.ChangeRequest.Actions.ApplyApproval do
  @moduledoc """
  Approved: replays the held action with its input, as the maker (the
  checker's approval stands in for the maker's permission), marked so the
  maker-checker hook lets it through. A change that no longer applies
  (e.g. the record was deleted) is marked failed with the reason.
  Rejected: recorded as rejected.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Workflow.ChangeRequest

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]

    request =
      Ash.get!(ChangeRequest, input.arguments.change_request_id, opts ++ [load: [:requested_by]])

    cond do
      request.status != :pending ->
        {:ok, request}

      input.arguments.outcome == :rejected ->
        outcome(request, %{status: :rejected}, opts)

      true ->
        case replay(request, input.tenant) do
          :ok -> outcome(request, %{status: :applied, applied_at: DateTime.utc_now()}, opts)
          {:error, message} -> outcome(request, %{status: :failed, error: message}, opts)
        end
    end
  end

  defp replay(request, tenant) do
    resource =
      String.to_existing_atom("Elixir." <> String.replace_prefix(request.resource, "Elixir.", ""))

    opts = [
      tenant: tenant,
      actor: request.requested_by,
      authorize?: false,
      context: %{maker_checker_apply: true}
    ]

    result =
      case request.action_type do
        :create ->
          resource
          |> Ash.Changeset.for_create(request.action, request.params, opts)
          |> Ash.create()

        :update ->
          with {:ok, record} <- Ash.get(resource, request.record_id, opts) do
            record
            |> Ash.Changeset.for_update(request.action, request.params, opts)
            |> Ash.update()
          end

        :destroy ->
          with {:ok, record} <- Ash.get(resource, request.record_id, opts) do
            record
            |> Ash.Changeset.for_destroy(request.action, request.params, opts)
            |> Ash.destroy()
          end
      end

    case result do
      {:error, error} ->
        {:error,
         error |> Ash.Error.to_error_class() |> Exception.message() |> String.slice(0, 1_000)}

      _ok ->
        :ok
    end
  end

  defp outcome(request, params, opts) do
    request
    |> Ash.Changeset.for_update(:set_outcome, params, opts)
    |> Ash.update(authorize?: false)
  end
end
