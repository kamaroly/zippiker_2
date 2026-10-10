defmodule ZippikerWeb.ProductionLive.Index do
  @moduledoc "Production orders with status filter and search; new orders open in a modal."
  use ZippikerWeb, :live_view

  alias Zippiker.{Inventory, Manufacturing}

  @statuses ~w(open draft confirmed in_progress done cancelled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Production orders")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    page =
      Manufacturing.list_production_orders!(
        %{query: query, status: status},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> stream(:orders, page.results, reset: true)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    opts = ash_opts(socket)
    boms = Manufacturing.list_boms!(%{active_only?: true}, opts)

    product_id =
      params["product_id"] || (List.first(boms) && List.first(boms).product_id)

    form =
      Manufacturing.ProductionOrder
      |> AshPhoenix.Form.for_create(:create,
        as: "order",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"product_id" => product_id, "quantity" => "1"}
      )
      |> to_form()

    assign(socket,
      form: form,
      boms: boms,
      warehouses: Inventory.list_warehouses!(opts)
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil)

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: orders_path(%{q: query, status: socket.assigns.status}))}
  end

  def handle_event("validate", %{"order" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"order" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Production order #{order.number} created")
         |> push_navigate(to: ~p"/manufacturing/orders/#{order}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp orders_path(params), do: query_path(~p"/manufacturing/orders", params)

  defp product_options(boms) do
    boms
    |> Enum.uniq_by(& &1.product_id)
    |> Enum.map(&{&1.product.name, &1.product_id})
  end

  defp bom_options(boms, product_id) do
    for bom <- boms, bom.product_id == product_id, do: {bom.reference, bom.id}
  end
end
