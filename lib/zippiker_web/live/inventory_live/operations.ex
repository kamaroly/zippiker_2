defmodule ZippikerWeb.InventoryLive.Operations do
  @moduledoc "Every stock operation (receipts, deliveries, adjustments), newest first."
  use ZippikerWeb, :live_view

  alias Zippiker.Inventory

  @kinds ~w(receipt delivery adjustment)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Stock movements")}

  @impl true
  def handle_params(params, _url, socket) do
    kind = if params["kind"] in @kinds, do: String.to_existing_atom(params["kind"])

    page =
      Inventory.list_stock_operations!(
        %{kind: kind},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(kind: kind, page: page)
     |> stream(:operations, page.results, reset: true)}
  end

  defp operations_path(params), do: query_path(~p"/inventory/operations", params)
end
