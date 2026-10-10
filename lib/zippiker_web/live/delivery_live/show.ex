defmodule ZippikerWeb.DeliveryLive.Show do
  @moduledoc "A delivery note: what was shipped, tracking, proof of delivery; print it."
  use ZippikerWeb, :live_view

  alias Zippiker.Sales

  @loads [
    :sales_order,
    :invoice,
    :warehouse,
    :shipped_by,
    :stock_operation,
    :legal_entity,
    customer: [:addresses],
    lines: [:product]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    note = Sales.get_delivery!(id, ash_opts(socket) ++ [load: @loads])
    {:ok, assign(socket, note: note, page_title: note.number)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       print?: socket.assigns.live_action == :print,
       confirming?: socket.assigns.live_action == :confirm
     )}
  end

  @impl true
  def handle_event("confirm", %{"confirmation" => params}, socket) do
    case Sales.confirm_delivery(socket.assigns.note, params, ash_opts(socket)) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(:note, Ash.load!(note, @loads, ash_opts(socket)))
         |> put_flash(:info, "Marked as delivered")
         |> push_patch(to: ~p"/deliveries/#{note}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end
end
