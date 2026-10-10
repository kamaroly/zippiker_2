defmodule ZippikerWeb.InventoryLive.Stock do
  @moduledoc "Stock on hand per product (all warehouses or one), valuation, and adjustments."
  use ZippikerWeb, :live_view

  alias Zippiker.{Catalog, Inventory}

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    {:ok,
     socket
     |> assign(:page_title, "Stock")
     |> assign(:warehouses, Inventory.list_warehouses!(%{active_only?: true}, opts))
     |> assign(:summary, Inventory.inventory_summary!(opts))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    warehouse = Enum.find(socket.assigns.warehouses, &(&1.id == params["warehouse"]))

    levels =
      Inventory.stock_levels!(
        %{query: query, warehouse_id: warehouse && warehouse.id},
        ash_opts(socket)
      )

    {:noreply,
     socket
     |> assign(query: query, warehouse: warehouse, empty?: levels == [])
     |> stream(:levels, levels, reset: true, dom_id: &"stock-#{&1.product.id}")
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :adjust, params) do
    products =
      Catalog.list_products!(%{tracked_only?: true, active_only?: true}, ash_opts(socket))

    form =
      Inventory.StockOperation
      |> AshPhoenix.Form.for_create(:adjust,
        as: "adjustment",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "product_id" => params["product_id"],
          "warehouse_id" => socket.assigns.warehouse && socket.assigns.warehouse.id,
          "date" => Date.to_iso8601(Date.utc_today())
        }
      )
      |> to_form()

    assign(socket, form: form, product_options: Enum.map(products, &{&1.name, &1.id}))
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :form, nil)

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: stock_path(query, socket.assigns.warehouse))}
  end

  def handle_event("validate", %{"adjustment" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"adjustment" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, operation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stock adjusted (#{operation.number})")
         |> assign(:summary, Inventory.inventory_summary!(ash_opts(socket)))
         |> push_patch(to: stock_path(socket.assigns.query, socket.assigns.warehouse))}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp stock_path(query, warehouse),
    do: query_path(~p"/inventory", %{q: query, warehouse: warehouse && warehouse.id})
end
