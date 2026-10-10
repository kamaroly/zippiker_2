defmodule ZippikerWeb.RfqLive.Index do
  @moduledoc "Requests for quotation sent to suppliers."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @statuses ~w(draft sent quoted accepted declined)

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, :page_title, "Requests for quotation")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Purchasing.list_rfqs!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:rfqs, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: rfqs_path(%{q: query, status: socket.assigns.status}))}
  end

  defp rfqs_path(params), do: query_path(~p"/rfqs", params)
end
