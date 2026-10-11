defmodule ZippikerWeb.WorkflowLive.ChangeRequests do
  @moduledoc """
  Maker-checker change requests: the list, and one request with its
  before/after diff, approve/reject for the checker and withdraw for the
  maker.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Workflow
  alias Zippiker.Workflow.{Approvers, MakerChecker}

  @statuses ~w(pending applied rejected cancelled failed)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Change requests")}

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    opts = ash_opts(socket)
    request = Workflow.get_change_request!(id, opts ++ [load: [:requested_by]])

    approval =
      request.approval_request_id &&
        Workflow.get_approval_request!(
          request.approval_request_id,
          opts ++ [load: [:requested_by, steps: [:user, :group, :decided_by]]]
        )

    {:noreply,
     assign(socket,
       request: request,
       approval: approval,
       page_title: request.number,
       can_decide?: can_decide?(approval, socket)
     )}
  end

  def handle_params(params, _url, socket) do
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Workflow.list_change_requests!(
        %{status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(request: nil, status: status, page: page)
     |> stream(:requests, page.results, reset: true)}
  end

  defp can_decide?(%{status: :pending} = approval, socket) do
    case Enum.find(approval.steps, &(&1.status == :pending)) do
      nil ->
        false

      step ->
        socket.assigns.current_user.id in Approvers.for_step(
          step,
          approval,
          socket.assigns.current_organization
        )
    end
  end

  defp can_decide?(_approval, _socket), do: false

  @impl true
  def handle_event("decide", %{"decision" => decision} = params, socket)
      when decision in ["approve", "reject"] do
    comment = params |> Map.get("comment", "") |> String.trim()

    if decision == "reject" and comment == "" do
      {:noreply, put_flash(socket, :error, "Say why you're rejecting it")}
    else
      case Workflow.decide_approval(
             socket.assigns.approval,
             String.to_existing_atom(decision),
             %{comment: if(comment == "", do: nil, else: comment)},
             ash_opts(socket)
           ) do
        {:ok, _approval} ->
          {:noreply,
           socket
           |> put_flash(:info, if(decision == "approve", do: "Approved", else: "Rejected"))
           |> push_patch(to: ~p"/approvals/changes/#{socket.assigns.request}")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, error_message(error))}
      end
    end
  end

  def handle_event("withdraw", _params, socket) do
    case Workflow.cancel_change_request(socket.assigns.request, ash_opts(socket)) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Change withdrawn")
         |> push_patch(to: ~p"/approvals/changes/#{request}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp changes_path(params), do: query_path(~p"/approvals/changes", params)

  defp scope_label(scope), do: MakerChecker.scope_label(scope)

  defp action_label(%{action_type: :create}), do: "Create"
  defp action_label(%{action_type: :destroy}), do: "Delete / archive"
  defp action_label(%{action: action}), do: Format.humanize(action)

  defp field_label(field),
    do: field |> to_string() |> String.trim_trailing("?") |> Format.humanize()
end
