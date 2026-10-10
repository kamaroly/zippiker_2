defmodule ZippikerWeb.DeliveryLive.Index do
  @moduledoc "Delivery notes: everything shipped to customers, and whether it arrived."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @statuses ~w(shipped delivered cancelled)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Delivery notes")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Sales.list_deliveries!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:notes, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: notes_path(%{q: query, status: socket.assigns.status}))}
  end

  defp notes_path(params), do: query_path(~p"/deliveries", params)
end
