defmodule Zippiker.Sales.Changes.PostToLedger do
  @moduledoc """
  Keeps the books in step with sales, inside the same transaction:

    * `event: :invoice_issued` – posts the invoice
    * `event: :invoice_voided` – reverses it
    * `event: :payment_recorded` – posts the payment
    * `event: :payment_removed` – reverses it

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
          :invoice_issued -> Accounting.post_invoice(record.id, ledger_opts)
          :invoice_voided -> Accounting.reverse_source(:invoice, record.id, ledger_opts)
          :payment_recorded -> Accounting.post_payment(record.id, ledger_opts)
          :payment_removed -> Accounting.reverse_source(:payment, record.id, ledger_opts)
        end

      case result do
        {:error, error} -> {:error, error}
        _ok -> {:ok, record}
      end
    end)
  end
end
