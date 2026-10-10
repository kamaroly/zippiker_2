defmodule Zippiker.Purchasing.Bill.Changes.ReturnUnorderedStock do
  @moduledoc "Voiding a bill reverses the stock receipt it created (if any) and cancels its note."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, bill ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      %{source: :bill, source_id: bill.id, kind: :receipt}
      |> Zippiker.Inventory.list_stock_operations!(opts)
      |> Enum.reject(&(&1.reversal_of_id || &1.reversal))
      |> Enum.reduce_while({:ok, bill}, fn operation, ok ->
        case Zippiker.Inventory.reverse_stock_operation(operation.id, opts) do
          {:ok, _reversal} -> {:cont, ok}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, bill} ->
          %{bill_id: bill.id}
          |> Zippiker.Purchasing.list_goods_receipts!(opts)
          |> Enum.each(fn note ->
            note |> Ash.Changeset.for_update(:cancel, %{}, opts) |> Ash.update!(authorize?: false)
          end)

          {:ok, bill}

        error ->
          error
      end
    end)
  end
end
