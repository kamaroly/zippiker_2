defmodule ZippikerWeb.DocumentLive.Print do
  @moduledoc """
  Print view of a quote, sales order, invoice or purchase order. "Save as PDF" in the browser's print
  dialog produces the PDF, so no PDF library is needed.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Purchasing, Sales}

  @sales_loads [:legal_entity, :lines, :contact, customer: [:addresses]]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    kind = socket.assigns.live_action
    opts = ash_opts(socket)

    document =
      case kind do
        :quote ->
          Sales.get_quote!(id, opts ++ [load: @sales_loads])

        :invoice ->
          Sales.get_invoice!(id, opts ++ [load: @sales_loads])

        :sales_order ->
          Sales.get_sales_order!(id, opts ++ [load: @sales_loads])

        :rfq ->
          Purchasing.get_rfq!(id, opts ++ [load: [:legal_entity, :lines, supplier: [:addresses]]])

        :purchase_order ->
          Purchasing.get_purchase_order!(
            id,
            opts ++ [load: [:legal_entity, :lines, supplier: [:addresses]]]
          )
      end

    {:ok,
     assign(socket,
       kind: kind,
       document: document,
       back: back_path(kind, document),
       page_title: document.number || "Draft invoice"
     )}
  end

  defp back_path(:quote, document), do: ~p"/quotes/#{document}"
  defp back_path(:invoice, document), do: ~p"/invoices/#{document}"
  defp back_path(:sales_order, document), do: ~p"/orders/#{document}"
  defp back_path(:purchase_order, document), do: ~p"/purchase-orders/#{document}"
  defp back_path(:rfq, document), do: ~p"/rfqs/#{document}"
end
