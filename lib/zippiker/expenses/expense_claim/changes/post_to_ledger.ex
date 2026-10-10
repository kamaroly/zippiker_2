defmodule Zippiker.Expenses.ExpenseClaim.Changes.PostToLedger do
  @moduledoc """
  Keeps the books in step with expense claims, inside the same transaction:
  `event: :approved` (expenses owed to the employee) or `:reimbursed`
  (the employee was paid back). See `Zippiker.Accounting.Ledger`.
  """
  use Ash.Resource.Change

  alias Zippiker.Accounting

  @impl true
  def change(changeset, opts, context) do
    event = Keyword.fetch!(opts, :event)

    Ash.Changeset.after_action(changeset, fn changeset, claim ->
      ledger_opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      result =
        case event do
          :approved -> Accounting.post_expense_claim(claim.id, ledger_opts)
          :reimbursed -> Accounting.post_expense_reimbursement(claim.id, ledger_opts)
        end

      case result do
        {:error, error} -> {:error, error}
        _ok -> {:ok, claim}
      end
    end)
  end
end
