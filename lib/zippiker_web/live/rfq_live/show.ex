defmodule ZippikerWeb.RfqLive.Show do
  @moduledoc "A request for quotation: send it, record the supplier's prices, order or decline."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @loads [:legal_entity, :lines, :owner, :purchase_order, supplier: [:addresses]]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    rfq = Purchasing.get_rfq!(id, ash_opts(socket) ++ [load: @loads])
    {:ok, assign(socket, rfq: rfq, page_title: rfq.number)}
  end

  @impl true
  def handle_event("transition", %{"to" => to}, socket) do
    action =
      %{
        "sent" => &Purchasing.send_rfq/2,
        "quoted" => &Purchasing.mark_rfq_quoted/2,
        "declined" => &Purchasing.decline_rfq/2,
        "draft" => &Purchasing.reopen_rfq/2
      }[to]

    case action && action.(socket.assigns.rfq, ash_opts(socket)) do
      {:ok, rfq} ->
        {:noreply,
         socket
         |> assign(:rfq, Ash.load!(rfq, @loads, ash_opts(socket)))
         |> put_flash(:info, "Request marked #{rfq.status}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("order", _params, socket) do
    case Purchasing.order_rfq(socket.assigns.rfq.id, ash_opts(socket)) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft purchase order created")
         |> push_navigate(to: ~p"/purchase-orders/#{order}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end
end
