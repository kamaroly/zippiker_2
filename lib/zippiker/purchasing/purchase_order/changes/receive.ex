defmodule Zippiker.Purchasing.PurchaseOrder.Changes.Receive do
  @moduledoc """
  Records what arrived: bumps each line's `received_quantity` (never past what
  was ordered), writes a goods received note (`GRN-…`) for everything that
  came, books stock-tracked lines into the warehouse (valued at the order's
  net unit price) and sets the status to received or partially received.
  """
  use Ash.Resource.Change

  alias Zippiker.Purchasing.PurchaseOrderLine

  @impl true
  def change(changeset, _opts, context) do
    opts = [tenant: changeset.tenant, authorize?: false]
    order = Ash.load!(changeset.data, [:supplier, lines: [:product]], opts)
    quantities = Ash.Changeset.get_argument(changeset, :quantities)

    arrivals =
      for line <- order.lines,
          remaining = PurchaseOrderLine.remaining(line),
          Decimal.gt?(remaining, 0),
          quantity = arriving(quantities, line, remaining),
          Decimal.gt?(quantity, 0),
          do: {line, quantity}

    if arrivals == [] do
      Ash.Changeset.add_error(changeset, field: :quantities, message: "nothing left to receive")
    else
      arrived = Map.new(arrivals, fn {line, quantity} -> {line.id, quantity} end)

      complete? =
        Enum.all?(order.lines, fn line ->
          received = Decimal.add(line.received_quantity, Map.get(arrived, line.id, 0))
          not Decimal.lt?(received, line.quantity)
        end)

      changeset
      |> Ash.Changeset.force_change_attribute(
        :status,
        if(complete?, do: :received, else: :partially_received)
      )
      |> Ash.Changeset.after_action(fn changeset, updated ->
        with :ok <- update_lines(arrivals, opts),
             {:ok, operation} <- book_stock(changeset, order, arrivals, context),
             {:ok, _note} <- write_note(changeset, order, arrivals, operation, context) do
          {:ok, updated}
        end
      end)
    end
  end

  defp arriving(nil, _line, remaining), do: remaining

  defp arriving(quantities, line, remaining) do
    case Decimal.parse(to_string(Map.get(quantities, line.id) || "0")) do
      {quantity, _rest} -> Decimal.min(quantity, remaining)
      :error -> Decimal.new(0)
    end
  end

  defp update_lines(arrivals, opts) do
    Enum.reduce_while(arrivals, :ok, fn {line, quantity}, :ok ->
      line
      |> Ash.Changeset.for_update(
        :set_received,
        %{received_quantity: Decimal.add(line.received_quantity, quantity)},
        opts
      )
      |> Ash.update(authorize?: false)
      |> case do
        {:ok, _line} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp write_note(changeset, order, arrivals, operation, context) do
    Zippiker.Purchasing.record_goods_receipt(
      Map.reject(
        %{
          received_on: Ash.Changeset.get_argument(changeset, :date),
          supplier_reference: Ash.Changeset.get_argument(changeset, :reference),
          legal_entity_id: order.legal_entity_id,
          supplier_id: order.supplier_id,
          purchase_order_id: order.id,
          warehouse_id: (operation && operation.warehouse_id) || order.warehouse_id,
          stock_operation_id: operation && operation.id,
          lines:
            arrivals
            |> Enum.with_index()
            |> Enum.map(fn {{line, quantity}, index} ->
              %{
                position: index,
                description: line.description,
                unit: line.unit,
                quantity: quantity,
                product_id: line.product_id,
                purchase_order_line_id: line.id
              }
            end)
        },
        fn {_key, value} -> is_nil(value) end
      ),
      tenant: changeset.tenant,
      actor: context.actor,
      authorize?: false
    )
  end

  defp book_stock(changeset, order, arrivals, context) do
    lines =
      for {line, quantity} <- arrivals, line.product && line.product.track_inventory? do
        %{
          product_id: line.product_id,
          quantity: quantity,
          unit_cost: PurchaseOrderLine.unit_cost(line)
        }
      end

    if lines == [] do
      {:ok, nil}
    else
      Zippiker.Inventory.record_stock_operation(
        %{
          kind: :receipt,
          date: Ash.Changeset.get_argument(changeset, :date),
          warehouse_id:
            Ash.Changeset.get_argument(changeset, :warehouse_id) || order.warehouse_id,
          legal_entity_id: order.legal_entity_id,
          memo: "Received from #{order.supplier.name}",
          source: :purchase_order,
          source_id: order.id,
          source_label: order.number,
          party_id: order.supplier_id,
          reference: Ash.Changeset.get_argument(changeset, :reference),
          lines: lines
        },
        tenant: changeset.tenant,
        actor: context.actor,
        authorize?: false
      )
    end
  end
end
