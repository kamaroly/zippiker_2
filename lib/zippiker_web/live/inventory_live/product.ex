defmodule ZippikerWeb.InventoryLive.Product do
  @moduledoc "One product's stock: on hand, average cost and every movement."
  use ZippikerWeb, :live_view

  alias Zippiker.{Catalog, Inventory}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = ash_opts(socket)
    product = Catalog.get_product!(id, opts ++ [load: [:on_hand, :stock_value, :low_stock?]])

    {:ok,
     socket
     |> assign(page_title: product.name, product: product)
     |> stream(:movements, Inventory.product_movements!(product.id, opts))}
  end
end
