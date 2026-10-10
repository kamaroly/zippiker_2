defmodule ZippikerWeb.QuoteLive.Index do
  @moduledoc "All quotes with status filter and search."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @statuses ~w(draft sent accepted declined)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Quotes")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Sales.list_quotes!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:quotes, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: quotes_path(%{q: query, status: socket.assigns.status}))}
  end

  defp quotes_path(params), do: query_path(~p"/quotes", params)
end
