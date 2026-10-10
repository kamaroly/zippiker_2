defmodule ZippikerWeb.ExpenseLive.Approvals do
  @moduledoc "The approver's inbox: claims waiting on the current user's decision."
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

  defp document_path(%{document_type: :expense_claim, document_id: id}), do: ~p"/expenses/#{id}"
end
