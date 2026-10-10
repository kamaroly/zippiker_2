defmodule Zippiker.Purchasing.Changes.PostToLedger do
  @moduledoc """
  Keeps the books in step with purchasing, inside the same transaction:
  `event: :bill_approved | :bill_voided | :payment_recorded | :payment_removed`.
  See `Zippiker.Accounting.Ledger` for the debits and credits.
  """
  use Ash.Resource.Change

  alias Zippiker.Accounting

  @impl true
  def change(changeset, opts, context) do
    event = Keyword.fetch!(opts, :event)

    Ash.Changeset.after_action(changeset, fn changeset, record ->
      ledger_opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      result =
        case event do
          :bill_approved -> Accounting.post_bill(record.id, ledger_opts)
          :bill_voided -> Accounting.reverse_source(:bill, record.id, ledger_opts)
          :payment_recorded -> Accounting.post_bill_payment(record.id, ledger_opts)
          :payment_removed -> Accounting.reverse_source(:bill_payment, record.id, ledger_opts)
        end

      case result do
        {:error, error} -> {:error, error}
        _ok -> {:ok, record}
      end
    end)
  end
end
