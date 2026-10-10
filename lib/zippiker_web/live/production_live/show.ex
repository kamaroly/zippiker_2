defmodule ZippikerWeb.ProductionLive.Show do
  @moduledoc """
  A production order: what's needed for the rest of the run (with stock
  shortages), the operations and estimated cost, the runs recorded so far,
  and the next step (confirm, record output, finish or cancel).
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Inventory, Manufacturing}
  alias Zippiker.Manufacturing.Costing

  @bom_loads [components: [product: [:on_hand]], operations: [:work_center]]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Manufacturing.get_production_order(id, ash_opts(socket)) do
      {:ok, _order} ->
        {:ok, load(socket, id)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Production order not found")
         |> push_navigate(to: ~p"/manufacturing/orders")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :edit) do
    if socket.assigns.order.status in [:draft, :confirmed] do
      form =
        socket.assigns.order
        |> AshPhoenix.Form.for_update(:update,
          as: "order",
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_organization
        )
        |> to_form()

      assign(socket,
        form: form,
        warehouses: Inventory.list_warehouses!(ash_opts(socket)),
        boms:
          Manufacturing.list_boms!(
            %{product_id: socket.assigns.order.product_id},
            ash_opts(socket)
          )
      )
    else
      push_patch(socket, to: ~p"/manufacturing/orders/#{socket.assigns.order}")
    end
  end

  defp apply_action(socket, _action), do: assign(socket, :form, nil)

  defp load(socket, id) do
    opts = ash_opts(socket)

    order =
      Manufacturing.get_production_order!(
        id,
        opts ++
          [
            load: [
              :product,
              :owner,
              :warehouse,
              :legal_entity,
              :remaining_quantity,
              bom: @bom_loads
            ]
          ]
      )

    planned =
      if Decimal.gt?(order.remaining_quantity, 0),
        do: order.remaining_quantity,
        else: order.quantity

    runs =
      Inventory.list_stock_operations!(
        %{source: :production_order, source_id: order.id},
        opts
      )

    assign(socket,
      order: order,
      page_title: order.number,
      planned: planned,
      requirements: Costing.requirements(order.bom, planned),
      operations: Costing.operations(order.bom, planned),
      estimate: Costing.estimate(order.bom, planned),
      runs: runs,
      currency: order.legal_entity.currency
    )
  end

  @impl true
  def handle_event("validate", %{"order" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"order" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order updated")
         |> load(order.id)
         |> push_patch(to: ~p"/manufacturing/orders/#{order}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("confirm", _params, socket),
    do: run(socket, &Manufacturing.confirm_production_order/2, "Order confirmed")

  def handle_event("finish", _params, socket),
    do: run(socket, &Manufacturing.finish_production_order/2, "Order closed")

  def handle_event("cancel", _params, socket),
    do: run(socket, &Manufacturing.cancel_production_order/2, "Order cancelled")

  def handle_event("produce", %{"produce" => params}, socket) do
    case Manufacturing.record_production(
           socket.assigns.order,
           params["quantity"],
           %{date: params["date"]},
           ash_opts(socket)
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(order.status == :done,
             do: "Production complete",
             else: "Recorded #{params["quantity"]} produced"
           )
         )
         |> load(order.id)
         |> push_patch(to: ~p"/manufacturing/orders/#{order}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp run(socket, fun, message) do
    case fun.(socket.assigns.order, ash_opts(socket)) do
      {:ok, order} -> {:noreply, socket |> put_flash(:info, message) |> load(order.id)}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp money(value, currency), do: Format.money(Money.new!(currency, value))
end
