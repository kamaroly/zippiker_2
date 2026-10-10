defmodule Zippiker.Inventory.StockOperation.Changes.PostToLedger do
  @moduledoc """
  Posts the operation's value to the books in the same transaction (see
  `Zippiker.Accounting.Ledger`). A reversal reverses the original's entry.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, operation ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      result =
        if operation.reversal_of_id,
          do: Zippiker.Accounting.reverse_source(:stock, operation.reversal_of_id, opts),
          else: Zippiker.Accounting.post_stock_operation(operation.id, opts)

      case result do
        {:error, error} -> {:error, error}
        _ok -> {:ok, operation}
      end
    end)
  end
end
