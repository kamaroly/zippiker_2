defmodule Zippiker.Sales.SalesOrder.Changes.Deliver do
  @moduledoc """
  Ships what's going out now: bumps each line's `delivered_quantity` (never
  past what was ordered), writes a delivery note (`DN-…`), takes
  stock-tracked lines out of the warehouse and sets the status to delivered
  or partially delivered.
  """
  use Ash.Resource.Change

  alias Zippiker.Sales.SalesOrderLine

  @impl true
  def change(changeset, _opts, context) do
    opts = [tenant: changeset.tenant, authorize?: false]
    order = Ash.load!(changeset.data, [:customer, lines: [:product]], opts)
    quantities = Ash.Changeset.get_argument(changeset, :quantities)

    items =
      for line <- order.lines,
          remaining = SalesOrderLine.remaining(line),
          Decimal.gt?(remaining, 0),
          quantity = going(quantities, line, remaining),
          Decimal.gt?(quantity, 0),
          do: {line, quantity}

    if items == [] do
      Ash.Changeset.add_error(changeset, field: :quantities, message: "nothing left to deliver")
    else
      going = Map.new(items, fn {line, quantity} -> {line.id, quantity} end)

      complete? =
        Enum.all?(order.lines, fn line ->
          delivered = Decimal.add(line.delivered_quantity, Map.get(going, line.id, 0))
          not Decimal.lt?(delivered, line.quantity)
        end)

      changeset
      |> Ash.Changeset.force_change_attribute(
        :status,
        if(complete?, do: :delivered, else: :partially_delivered)
      )
      |> then(fn changeset ->
        if complete?,
          do: Ash.Changeset.force_change_attribute(changeset, :delivered_at, DateTime.utc_now()),
          else: changeset
      end)
      |> Ash.Changeset.after_action(fn changeset, updated ->
        extra = %{
          date: Ash.Changeset.get_argument(changeset, :date),
          carrier: Ash.Changeset.get_argument(changeset, :carrier),
          tracking_number: Ash.Changeset.get_argument(changeset, :tracking_number)
        }

        with :ok <- SalesOrderLine.add_delivered(items, opts),
             {:ok, _delivery} <-
               Zippiker.Sales.Shipping.deliver(
                 order,
                 items,
                 :sales_order,
                 opts ++ [actor: context.actor],
                 extra
               ) do
          {:ok, updated}
        end
      end)
    end
  end

  defp going(nil, _line, remaining), do: remaining

  defp going(quantities, line, remaining) do
    case Decimal.parse(to_string(Map.get(quantities, line.id) || "0")) do
      {quantity, _rest} -> Decimal.min(quantity, remaining)
      :error -> Decimal.new(0)
    end
  end
end
