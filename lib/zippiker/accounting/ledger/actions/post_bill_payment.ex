defmodule Zippiker.Accounting.Ledger.Actions.PostBillPayment do
  @moduledoc "Supplier paid: debit accounts payable, credit cash/bank/mobile money."
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    payment =
      Ash.get!(Zippiker.Purchasing.BillPayment, input.arguments.bill_payment_id,
        tenant: input.tenant,
        authorize?: false,
        load: [bill: [:supplier]]
      )

    Posting.once(:bill_payment, payment.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      amount = Money.to_decimal(payment.amount)
      bill = payment.bill
      memo = "Paid #{bill.number} · #{bill.supplier.name}"

      Posting.post(
        %{
          date: payment.paid_on,
          memo: memo,
          legal_entity_id: bill.legal_entity_id,
          branch_id: bill.branch_id,
          source: :bill_payment,
          source_id: payment.id,
          source_label: bill.supplier_reference || bill.number,
          lines: [
            %{
              account_id: keys.payable,
              debit: amount,
              party_id: bill.supplier_id,
              description: memo
            },
            %{
              account_id: SystemAccounts.for_method(keys, payment.method),
              credit: amount,
              description: memo
            }
          ]
        },
        opts ++ [actor: context.actor]
      )
    end)
  end
end
