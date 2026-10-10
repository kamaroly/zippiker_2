defmodule ZippikerWeb.InvoiceLive.Index do
  @moduledoc "All invoices with status (incl. overdue) filter and search."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @statuses ~w(draft issued overdue paid void)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Invoices")
     |> assign(:summary, Sales.sales_summary!(ash_opts(socket)))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Sales.list_invoices!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:invoices, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: invoices_path(%{q: query, status: socket.assigns.status}))}
  end

  defp invoices_path(params), do: query_path(~p"/invoices", params)
end
