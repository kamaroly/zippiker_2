defmodule Zippiker.Accounting.Ledger.Actions.PostExpenseClaim do
  @moduledoc """
  Expense claim approved: debit each item's category expense account (Other
  expenses when the category has none), credit "Employee reimbursements" —
  the business now owes the employee.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    claim =
      Zippiker.Expenses.get_expense_claim!(input.arguments.claim_id,
        tenant: input.tenant,
        authorize?: false,
        load: [:claimant, :employee, items: [:category]]
      )

    Posting.once(:expense_claim, claim.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      memo = "Expense claim #{claim.number} · #{claimant_name(claim)}"

      debits =
        claim.items
        |> Enum.map(&{&1.category.account_id || keys.expense, &1.amount})
        |> Posting.net_by_account()

      Posting.post(
        %{
          date: DateTime.to_date(claim.approved_at || DateTime.utc_now()),
          memo: memo,
          legal_entity_id: claim.legal_entity_id,
          source: :expense_claim,
          source_id: claim.id,
          source_label: claim.number,
          lines:
            Posting.lines(debits, memo) ++
              [
                %{
                  account_id: keys.reimbursements,
                  credit: Money.to_decimal(claim.total),
                  party_id: claim.employee && claim.employee.party_id,
                  description: memo
                }
              ]
        },
        opts ++ [actor: context.actor]
      )
    end)
  end

  @doc false
  def claimant_name(%{claimant: claimant}), do: claimant.name || to_string(claimant.email)
end
