defmodule ZippikerWeb.GoodsReceiptLive.Index do
  @moduledoc "Goods received notes: everything that arrived from suppliers."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Goods received")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""

    page =
      Purchasing.list_goods_receipts!(
        %{query: query},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, page: page)
     |> stream(:notes, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: query_path(~p"/goods-receipts", %{q: query}))}
  end
end
