defmodule Zippiker.Expenses.ExpenseClaim do
  @moduledoc """
  An employee's request to be paid back for business expenses:
  draft → submitted (in approval) → approved → reimbursed, or rejected (edit
  and resubmit) / cancelled. Approval is posted to the books (expense accounts
  against "Employee reimbursements"); reimbursing clears it from cash, bank
  or mobile money.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Expenses,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource],
    fragments: [
      Zippiker.Expenses.ExpenseClaim.Attributes,
      Zippiker.Expenses.ExpenseClaim.Relationships,
      Zippiker.Expenses.ExpenseClaim.Actions,
      Zippiker.Expenses.ExpenseClaim.Policies
    ]

  postgres do
    table "expense_claims"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :restrict
      reference :claimant, on_delete: :restrict
      reference :employee, on_delete: :nilify
      reference :approval_request, on_delete: :nilify
    end

    custom_indexes do
      index [:status]
      index [:claimant_id]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    reference_source? false
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  multitenancy do
    strategy :context
  end
end
