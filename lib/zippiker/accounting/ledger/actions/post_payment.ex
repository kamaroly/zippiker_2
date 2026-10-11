defmodule Zippiker.Accounting.Ledger.Actions.PostPayment do
  @moduledoc "Payment received: debit cash/bank/mobile money, credit receivable."
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    payment =
      Ash.get!(Zippiker.Sales.Payment, input.arguments.payment_id,
        tenant: input.tenant,
        authorize?: false,
        load: [invoice: [:customer]]
      )

    Posting.once(:payment, payment.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      amount = Money.to_decimal(payment.amount)
      invoice = payment.invoice
      memo = "Payment for #{invoice.number} · #{invoice.customer.name}"

      Posting.post(
        %{
          date: payment.paid_on,
          memo: memo,
          legal_entity_id: invoice.legal_entity_id,
          branch_id: invoice.branch_id,
          source: :payment,
          source_id: payment.id,
          source_label: invoice.number,
          lines: [
            %{
              account_id: SystemAccounts.for_method(keys, payment.method),
              debit: amount,
              description: memo
            },
            %{
              account_id: keys.receivable,
              credit: amount,
              party_id: invoice.customer_id,
              description: memo
            }
          ]
        },
        opts ++ [actor: context.actor]
      )
    end)
  end
end
