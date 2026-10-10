defmodule Zippiker.Accounting do
  @moduledoc """
  Double-entry bookkeeping: a chart of accounts, an immutable journal, and
  postings generated from other modules (invoices and payments today, bills
  and stock later). Entries are never edited; mistakes are reversed.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Accounting.Account do
      define :list_accounts, action: :list
      define :get_account, action: :read, get_by: [:id]
      define :create_account, action: :create
      define :update_account, action: :update
      define :delete_account, action: :destroy
    end

    resource Zippiker.Accounting.JournalEntry do
      define :list_journal_entries, action: :search
      define :get_journal_entry, action: :read, get_by: [:id]
      define :create_journal_entry, action: :create
      define :reverse_journal_entry, action: :reverse, args: [:entry_id]
      define :record_expense, action: :expense
    end

    resource Zippiker.Accounting.JournalLine do
      define :account_lines, action: :for_account, args: [:account_id]
    end

    resource Zippiker.Accounting.Ledger do
      define :setup_books, action: :setup
      define :sync_sales, action: :sync_sales
      define :post_invoice, action: :post_invoice, args: [:invoice_id]
      define :post_payment, action: :post_payment, args: [:payment_id]
      define :post_bill, action: :post_bill, args: [:bill_id]
      define :post_bill_payment, action: :post_bill_payment, args: [:bill_payment_id]
      define :post_stock_operation, action: :post_stock_operation, args: [:operation_id]
      define :post_expense_claim, action: :post_expense_claim, args: [:claim_id]

      define :post_expense_reimbursement,
        action: :post_expense_reimbursement,
        args: [:claim_id]

      define :reverse_source, action: :reverse_source, args: [:source, :source_id]
    end

    resource Zippiker.Accounting.Reports do
      define :accounting_overview, action: :overview
      define :trial_balance, action: :trial_balance, args: [:as_of]
      define :profit_and_loss, action: :profit_and_loss, args: [:from, :to]
      define :balance_sheet, action: :balance_sheet, args: [:as_of]
    end
  end
end
