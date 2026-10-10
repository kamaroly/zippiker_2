defmodule Zippiker.Expenses do
  @moduledoc """
  Employee expense claims: an employee lists what they paid out of pocket,
  submits the claim through the workspace's approval workflow
  (`Zippiker.Workflow`), and once approved it is posted to the books (expense
  accounts against "Employee reimbursements") and paid back.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Zippiker.Expenses.ExpenseCategory do
      define :list_expense_categories, action: :list
      define :get_expense_category, action: :read, get_by: [:id]
      define :create_expense_category, action: :create
      define :update_expense_category, action: :update
      define :delete_expense_category, action: :destroy
    end

    resource Zippiker.Expenses.ExpenseClaim do
      define :list_expense_claims, action: :search
      define :get_expense_claim, action: :read, get_by: [:id]
      define :create_expense_claim, action: :create
      define :update_expense_claim, action: :update
      define :submit_expense_claim, action: :submit
      define :reimburse_expense_claim, action: :reimburse
      define :cancel_expense_claim, action: :cancel
      define :delete_expense_claim, action: :destroy
      define :apply_approval, action: :apply_approval, args: [:claim_id, :outcome]
    end

    resource Zippiker.Expenses.ExpenseItem
  end
end
