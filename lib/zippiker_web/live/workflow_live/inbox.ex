defmodule ZippikerWeb.WorkflowLive.Inbox do
  @moduledoc """
  The approver's inbox across every module: whatever is waiting on the
  current user's decision (expense claims today; leave, change requests,
  journal postings as they join the workflow engine).
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Workflow

  @impl true
  def mount(_params, _session, socket) do
    requests = Workflow.approval_inbox!(ash_opts(socket))

    {:ok,
     socket
     |> assign(page_title: "Approvals", count: length(requests))
     |> stream(:requests, requests)}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  defp current_step(request), do: Enum.find(request.steps, &(&1.status == :pending))
end
