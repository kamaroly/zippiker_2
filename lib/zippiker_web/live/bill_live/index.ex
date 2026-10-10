defmodule ZippikerWeb.BillLive.Index do
  @moduledoc "Supplier bills with status (incl. overdue) filter and search."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @statuses ~w(draft open overdue paid void)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Bills")
     |> assign(:summary, Purchasing.payables_summary!(ash_opts(socket)))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Purchasing.list_bills!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:bills, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: bills_path(%{q: query, status: socket.assigns.status}))}
  end

  defp bills_path(params), do: query_path(~p"/bills", params)
end
