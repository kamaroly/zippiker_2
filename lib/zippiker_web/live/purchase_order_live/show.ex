defmodule ZippikerWeb.PurchaseOrderLive.Show do
  @moduledoc "A purchase order: place it, receive goods (all or part), bill it, cancel it."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing
  alias Zippiker.Purchasing.PurchaseOrderLine

  @loads [
    :legal_entity,
    :owner,
    :warehouse,
    :bill,
    :rfq,
    lines: [:product],
    supplier: [:addresses]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Purchasing.get_purchase_order(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, order} ->
        {:ok, socket |> assign(page_title: order.number) |> assign_order(order)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Purchase order not found")
         |> push_navigate(to: ~p"/purchase-orders")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :receiving?, socket.assigns.live_action == :receive)}
  end

  @impl true
  def handle_event("transition", %{"to" => to}, socket) do
    action =
      %{
        "ordered" => &Purchasing.place_purchase_order/2,
        "cancelled" => &Purchasing.cancel_purchase_order/2
      }[to]

    case action && action.(socket.assigns.order, ash_opts(socket)) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign_order(Ash.load!(order, @loads, ash_opts(socket)))
         |> put_flash(
           :info,
           "Purchase order #{Format.humanize(order.status) |> String.downcase()}"
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("receive", %{"receive" => params}, socket) do
    case Purchasing.receive_purchase_order(
           socket.assigns.order,
           %{
             quantities: params["quantities"] || %{},
             date: params["date"],
             reference: params["reference"]
           },
           ash_opts(socket)
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign_order(Ash.load!(order, @loads, ash_opts(socket)))
         |> put_flash(:info, "Goods received. The goods received note is under Receipts.")
         |> push_patch(to: ~p"/purchase-orders/#{order}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("bill", _params, socket) do
    case Purchasing.bill_purchase_order(socket.assigns.order.id, ash_opts(socket)) do
      {:ok, bill} ->
        {:noreply,
         socket |> put_flash(:info, "Draft bill created") |> push_navigate(to: ~p"/bills/#{bill}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp assign_order(socket, order) do
    receipts = Purchasing.list_goods_receipts!(%{purchase_order_id: order.id}, ash_opts(socket))

    assign(socket, order: order, receipts: receipts)
  end

  defp remaining(line), do: PurchaseOrderLine.remaining(line)
end
