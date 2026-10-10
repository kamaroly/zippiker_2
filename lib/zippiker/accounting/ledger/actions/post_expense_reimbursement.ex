defmodule Zippiker.Accounting.Ledger.Actions.PostExpenseReimbursement do
  @moduledoc "Employee paid back: debit \"Employee reimbursements\", credit cash/bank/mobile money."
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.Actions.PostExpenseClaim
  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    claim =
      Zippiker.Expenses.get_expense_claim!(input.arguments.claim_id,
        tenant: input.tenant,
        authorize?: false,
        load: [:claimant, :employee]
      )

    Posting.once(:expense_reimbursement, claim.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      amount = Money.to_decimal(claim.total)
      memo = "Reimbursed #{claim.number} · #{PostExpenseClaim.claimant_name(claim)}"

      Posting.post(
        %{
          date: claim.reimbursed_on || Date.utc_today(),
          memo: memo,
          legal_entity_id: claim.legal_entity_id,
          source: :expense_reimbursement,
          source_id: claim.id,
          source_label: claim.reimbursement_reference || claim.number,
          lines: [
            %{
              account_id: keys.reimbursements,
              debit: amount,
              party_id: claim.employee && claim.employee.party_id,
              description: memo
            },
            %{
              account_id: SystemAccounts.for_method(keys, claim.reimbursed_from),
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
