defmodule Zippiker.Accounting.Ledger.Actions.PostStockOperation do
  @moduledoc """
  Values a stock operation: receipts on a PO debit inventory against "goods
  received not billed", deliveries move inventory to cost of sales, and
  adjustments go to inventory adjustments. Production consumes components
  and receives finished goods at components + labour/overhead, so the net
  increase in inventory is credited to "Manufacturing overhead applied". Receipts that came with a bill
  (the bill carries the value), reversals (handled by `reverse_source`) and
  zero-value operations post nothing.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    operation =
      Zippiker.Inventory.get_stock_operation!(input.arguments.operation_id,
        tenant: input.tenant,
        authorize?: false,
        load: [:movements, :warehouse]
      )

    net =
      operation.movements
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, Decimal.mult(&1.quantity, &1.unit_cost)))
      |> Decimal.round(2)

    cond do
      operation.reversal_of_id || operation.source == :bill || Decimal.eq?(net, 0) ->
        {:ok, nil}

      true ->
        Posting.once(:stock, operation.id, opts, fn ->
          keys = SystemAccounts.fetch(input.tenant)
          {debit, credit} = accounts(operation.kind, net, keys)
          value = Decimal.abs(net)
          memo = memo(operation)

          Posting.post(
            %{
              date: operation.date,
              memo: memo,
              legal_entity_id: operation.legal_entity_id,
              branch_id: operation.warehouse && operation.warehouse.branch_id,
              source: :stock,
              source_id: operation.id,
              source_label: operation.number,
              lines: [
                %{account_id: debit, debit: value, description: memo},
                %{account_id: credit, credit: value, description: memo}
              ]
            },
            opts ++ [actor: context.actor]
          )
        end)
    end
  end

  defp accounts(:receipt, _net, keys), do: {keys.inventory, keys.grni}
  defp accounts(:delivery, _net, keys), do: {keys.cost_of_sales, keys.inventory}

  defp accounts(:production, _net, keys), do: {keys.inventory, keys.production_overhead}

  defp accounts(:adjustment, net, keys) do
    if Decimal.gt?(net, 0),
      do: {keys.inventory, keys.inventory_adjustment},
      else: {keys.inventory_adjustment, keys.inventory}
  end

  defp memo(%{kind: :receipt} = operation), do: "Goods received #{operation.number}"
  defp memo(%{kind: :delivery} = operation), do: "Goods delivered #{operation.number}"

  defp memo(%{kind: :production} = operation),
    do: "Production #{operation.number} · #{operation.source_label}"

  defp memo(operation), do: "Stock adjustment #{operation.number}"
end
