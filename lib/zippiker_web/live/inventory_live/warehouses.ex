defmodule ZippikerWeb.InventoryLive.Warehouses do
  @moduledoc "Places stock is kept; admins add and edit them."
  use ZippikerWeb, :live_view

  alias Zippiker.Inventory

  @impl true
  def mount(_params, _session, socket) do
    Inventory.default_warehouse!(ash_opts(socket))

    {:ok,
     socket
     |> assign(page_title: "Warehouses", branch_options: branch_options(socket.assigns))
     |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Inventory.Warehouse
      |> AshPhoenix.Form.for_create(:create,
        as: "warehouse",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, warehouse: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    warehouse = Inventory.get_warehouse!(id, ash_opts(socket))

    form =
      warehouse
      |> AshPhoenix.Form.for_update(:update,
        as: "warehouse",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, warehouse: warehouse)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, warehouse: nil)

  @impl true
  def handle_event("validate", %{"warehouse" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"warehouse" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _warehouse} ->
        {:noreply,
         socket
         |> put_flash(:info, "Warehouse saved")
         |> load()
         |> push_patch(to: ~p"/inventory/warehouses")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp load(socket),
    do: stream(socket, :warehouses, Inventory.list_warehouses!(ash_opts(socket)), reset: true)
end
