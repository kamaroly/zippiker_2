defmodule ZippikerWeb.SalesOrderLive.Show do
  @moduledoc "A sales order: the document plus confirm, deliver, invoice and cancel."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales
  alias Zippiker.Sales.SalesOrderLine

  @loads [
    :legal_entity,
    :contact,
    :deal,
    :quote,
    :invoice,
    :owner,
    :warehouse,
    lines: [:product],
    customer: [:addresses]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Sales.get_sales_order(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, order} ->
        {:ok, socket |> assign(page_title: order.number) |> assign_order(order)}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Order not found") |> push_navigate(to: ~p"/orders")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :delivering?, socket.assigns.live_action == :deliver)}
  end

  @impl true
  def handle_event("deliver", %{"deliver" => params}, socket) do
    case Sales.deliver_sales_order(
           socket.assigns.order,
           %{
             quantities: params["quantities"] || %{},
             date: params["date"],
             carrier: params["carrier"],
             tracking_number: params["tracking_number"]
           },
           ash_opts(socket)
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign_order(Ash.load!(order, @loads, ash_opts(socket)))
         |> put_flash(:info, "Shipped. The delivery note is under Deliveries.")
         |> push_patch(to: ~p"/orders/#{order}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("transition", %{"to" => to}, socket) do
    action =
      %{
        "confirmed" => &Sales.confirm_sales_order/2,
        "cancelled" => &Sales.cancel_sales_order/2
      }[to]

    case action && action.(socket.assigns.order, ash_opts(socket)) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign_order(Ash.load!(order, @loads, ash_opts(socket)))
         |> put_flash(:info, "Order #{Format.humanize(order.status) |> String.downcase()}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("invoice", _params, socket) do
    case Sales.invoice_sales_order(socket.assigns.order.id, ash_opts(socket)) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft invoice created")
         |> push_navigate(to: ~p"/invoices/#{invoice}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp assign_order(socket, order) do
    opts = ash_opts(socket)

    # Notes written by the order itself and by its invoice.
    deliveries =
      [%{sales_order_id: order.id}, order.invoice && %{invoice_id: order.invoice.id}]
      |> Enum.filter(& &1)
      |> Enum.flat_map(&Sales.list_deliveries!(&1, opts))
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.number)

    assign(socket, order: order, deliveries: deliveries)
  end

  defp remaining(line), do: SalesOrderLine.remaining(line)
end
