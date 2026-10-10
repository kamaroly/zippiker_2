defmodule ZippikerWeb.ExpenseLive.Index do
  @moduledoc "Expense claims: the actor's own (`:mine`) or everyone's (`:all`)."
  use ZippikerWeb, :live_view

  alias Zippiker.{Expenses, Workflow}

  @statuses ~w(draft submitted approved rejected reimbursed cancelled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :inbox_count, length(Workflow.approval_inbox!(ash_opts(socket))))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    mine? = socket.assigns.live_action == :mine
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Expenses.list_expense_claims!(
        %{query: query, status: status, mine?: mine?},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(
       page_title: if(mine?, do: "My expense claims", else: "All expense claims"),
       mine?: mine?,
       query: query,
       status: status,
       page: page
     )
     |> stream(:claims, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to: claims_path(socket.assigns, %{q: query, status: socket.assigns.status})
     )}
  end

  defp claims_path(%{mine?: true}, params), do: query_path(~p"/expenses", params)
  defp claims_path(_assigns, params), do: query_path(~p"/expenses/all", params)
end
