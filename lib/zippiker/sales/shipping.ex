defmodule Zippiker.Sales.Shipping do
  @moduledoc """
  Sends goods for a sales document: writes the delivery note (`DN-…`) for
  every physical line and takes stock-tracked products out of the warehouse
  (`MV-…`). Used by sales orders (deliver, in parts) and invoices (issue);
  `return/3` undoes an invoice's shipments when it is voided.
  """

  @doc """
  Ships `items` (`{line, quantity}`). Only lines for products of kind goods
  are shipped; services and free-text lines aren't. `document` (an
  order or invoice) needs `customer`; lines need `product`. `extra` may set
  `date`, `carrier`, `tracking_number`, `warehouse_id`.
  """
  def deliver(document, items, source, opts, extra \\ %{}) do
    items =
      for {line, quantity} <- items,
          Decimal.gt?(quantity, 0),
          line.product && line.product.kind == :goods,
          do: {line, quantity}

    if items == [] do
      {:ok, nil}
    else
      warehouse_id = Map.get(extra, :warehouse_id) || Map.get(document, :warehouse_id)

      with {:ok, operation} <- move_stock(document, items, source, warehouse_id, extra, opts) do
        Zippiker.Sales.record_delivery(
          compact(%{
            shipped_on: Map.get(extra, :date),
            carrier: Map.get(extra, :carrier),
            tracking_number: Map.get(extra, :tracking_number),
            legal_entity_id: document.legal_entity_id,
            customer_id: document.customer_id,
            sales_order_id: order_id(document, source),
            invoice_id: if(source == :invoice, do: document.id),
            warehouse_id: (operation && operation.warehouse_id) || warehouse_id,
            stock_operation_id: operation && operation.id,
            lines:
              items
              |> Enum.with_index()
              |> Enum.map(fn {{line, quantity}, index} ->
                %{
                  position: index,
                  description: line.description,
                  unit: line.unit,
                  quantity: quantity,
                  product_id: line.product_id,
                  sales_order_line_id: if(source == :sales_order, do: line.id)
                }
              end)
          }),
          opts
        )
      end
    end
  end

  defp compact(params), do: Map.reject(params, fn {_key, value} -> is_nil(value) end)

  defp order_id(document, :sales_order), do: document.id
  defp order_id(document, _source), do: Map.get(document, :sales_order_id)

  defp move_stock(document, items, source, warehouse_id, extra, opts) do
    lines =
      for {line, quantity} <- items,
          line.product && line.product.track_inventory?,
          do: %{product_id: line.product_id, quantity: quantity}

    if lines == [] do
      {:ok, nil}
    else
      Zippiker.Inventory.record_stock_operation(
        %{
          kind: :delivery,
          date: Map.get(extra, :date),
          warehouse_id: warehouse_id,
          legal_entity_id: document.legal_entity_id,
          memo: "Delivered to #{document.customer.name}",
          source: source,
          source_id: document.id,
          source_label: document.number,
          party_id: document.customer_id,
          reference: Map.get(extra, :tracking_number),
          lines: lines
        },
        opts
      )
    end
  end

  @doc "Returns everything an invoice shipped to stock and cancels its delivery notes."
  def return(source, source_id, opts) do
    result =
      %{source: source, source_id: source_id, kind: :delivery}
      |> Zippiker.Inventory.list_stock_operations!(opts)
      |> Enum.reject(&(&1.reversal_of_id || &1.reversal))
      |> Enum.reduce_while(:ok, fn operation, :ok ->
        case Zippiker.Inventory.reverse_stock_operation(operation.id, opts) do
          {:ok, _reversal} -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    with :ok <- result do
      %{invoice_id: source_id}
      |> Zippiker.Sales.list_deliveries!(opts)
      |> Enum.each(fn delivery ->
        delivery |> Ash.Changeset.for_update(:cancel, %{}, opts) |> Ash.update!(authorize?: false)
      end)

      :ok
    end
  end
end
