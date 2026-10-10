defmodule Zippiker.Manufacturing.ProductionOrder.Changes.RecordOutput do
  @moduledoc """
  Produces `quantity` units: checks the components are in stock, then (in
  the same transaction) records a `:production` stock operation that takes
  the components out at their average cost and brings the finished goods in
  at components + labour/overhead per unit. Updates the produced quantity,
  actual cost and status (done when the planned quantity is reached).
  """
  use Ash.Resource.Change

  alias Zippiker.Manufacturing.Costing

  @bom_loads [components: [product: [:on_hand]], operations: [:work_center]]

  @impl true
  def change(changeset, _opts, context) do
    quantity = Ash.Changeset.get_argument(changeset, :quantity)
    order = changeset.data
    opts = [tenant: changeset.tenant, authorize?: false]

    with %Decimal{} <- quantity,
         {:ok, bom} <- Zippiker.Manufacturing.get_bom(order.bom_id, opts ++ [load: @bom_loads]) do
      case Costing.shortages(bom, quantity) do
        [] ->
          produce(changeset, order, bom, quantity, context)

        short ->
          Ash.Changeset.add_error(changeset, field: :quantity, message: shortage_message(short))
      end
    else
      _ -> changeset
    end
  end

  defp produce(changeset, order, bom, quantity, context) do
    estimate = Costing.estimate(bom, quantity)
    produced = Decimal.add(order.produced_quantity, quantity)
    done? = not Decimal.lt?(produced, order.quantity)
    now = DateTime.utc_now()

    changeset
    |> Ash.Changeset.force_change_attributes(%{
      produced_quantity: produced,
      actual_cost: Decimal.add(order.actual_cost, estimate.total),
      status: if(done?, do: :done, else: :in_progress),
      started_at: order.started_at || now,
      finished_at: if(done?, do: now)
    })
    |> Ash.Changeset.after_action(fn changeset, order ->
      lines =
        Enum.map(Costing.requirements(bom, quantity), fn row ->
          %{
            product_id: row.product.id,
            quantity: Decimal.negate(row.required),
            unit_cost: row.unit_cost,
            signed: true
          }
        end) ++
          [
            %{
              product_id: order.product_id,
              quantity: quantity,
              unit_cost: estimate.unit_cost,
              signed: true
            }
          ]

      result =
        Zippiker.Inventory.record_stock_operation(
          %{
            kind: :production,
            date: Ash.Changeset.get_argument(changeset, :date) || Date.utc_today(),
            warehouse_id: order.warehouse_id,
            legal_entity_id: order.legal_entity_id,
            source: :production_order,
            source_id: order.id,
            source_label: order.number,
            memo: "Produced #{Decimal.normalize(quantity)} on #{order.number}",
            lines: lines
          },
          tenant: changeset.tenant,
          actor: context.actor,
          authorize?: false
        )

      case result do
        {:ok, _operation} -> {:ok, order}
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp shortage_message(rows) do
    details =
      Enum.map_join(rows, ", ", fn row ->
        "#{row.product.name} (short #{Decimal.normalize(row.shortage)})"
      end)

    "not enough components in stock: #{details}"
  end
end
