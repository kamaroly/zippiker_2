defmodule ZippikerWeb.InventoryLive.Operation do
  @moduledoc "A stock operation with its movements; adjustments can be reversed."
  use ZippikerWeb, :live_view

  alias Zippiker.Inventory

  @loads [:warehouse, :party, :created_by, :reversal, :reversal_of, movements: [:product]]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    operation = Inventory.get_stock_operation!(id, ash_opts(socket) ++ [load: @loads])
    {:ok, assign(socket, operation: operation, page_title: operation.number)}
  end

  @impl true
  def handle_event("reverse", _params, socket) do
    case Inventory.reverse_stock_operation(socket.assigns.operation.id, ash_opts(socket)) do
      {:ok, reversal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reversed with #{reversal.number}")
         |> push_navigate(to: ~p"/inventory/operations/#{reversal}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  # Receipts and deliveries are undone from their documents (void the bill or invoice).
  defp reversible?(operation, assigns) do
    admin?(assigns) and operation.kind == :adjustment and is_nil(operation.reversal) and
      is_nil(operation.reversal_of_id)
  end

  defp source_path(%{source: :purchase_order, source_id: id}), do: ~p"/purchase-orders/#{id}"
  defp source_path(%{source: :bill, source_id: id}), do: ~p"/bills/#{id}"
  defp source_path(%{source: :sales_order, source_id: id}), do: ~p"/orders/#{id}"
  defp source_path(%{source: :invoice, source_id: id}), do: ~p"/invoices/#{id}"

  defp source_path(%{source: :production_order, source_id: id}),
    do: ~p"/manufacturing/orders/#{id}"

  defp source_path(_operation), do: nil
end
