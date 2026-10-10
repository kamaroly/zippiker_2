defmodule ZippikerWeb.PurchaseOrderLive.Index do
  @moduledoc "Purchase orders with status filter and search."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @statuses ~w(draft open received cancelled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Purchase orders")
     |> assign(:summary, Purchasing.payables_summary!(ash_opts(socket)))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Purchasing.list_purchase_orders!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:orders, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: orders_path(%{q: query, status: socket.assigns.status}))}
  end

  defp orders_path(params), do: query_path(~p"/purchase-orders", params)
end
