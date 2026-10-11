defmodule ZippikerWeb.WorkflowLive.History do
  @moduledoc "Every approval in the workspace, by document type and outcome, with its timeline."
  use ZippikerWeb, :live_view

  alias Zippiker.Workflow
  alias Zippiker.Workflow.DocumentTypes

  @statuses ~w(pending approved rejected cancelled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Approval history", types: DocumentTypes.all(), open: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    type =
      Enum.find_value(DocumentTypes.all(), fn %{key: key} ->
        to_string(key) == params["type"] && key
      end)

    page =
      Workflow.list_approval_requests!(
        %{status: status, document_type: type},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(status: status, type: type, page: page)
     |> stream(:requests, page.results, reset: true)}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    request = Enum.find(socket.assigns.page.results, &(&1.id == id))
    open = if socket.assigns.open == id, do: nil, else: id
    {:noreply, socket |> assign(:open, open) |> stream_insert(:requests, request)}
  end

  defp history_path(params), do: query_path(~p"/approvals/history", params)
end
