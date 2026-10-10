defmodule Zippiker.Accounting.Ledger.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounting.Ledger.Actions

  actions do
    action :setup, :map do
      description "Creates the default chart of accounts (missing system accounts only, if one exists)."
      run Actions.Setup
    end

    action :sync_sales, :map do
      description "Posts issued invoices and payments that have no journal entry yet."
      run Actions.SyncSales
    end

    action :post_invoice, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :invoice_id, :uuid, allow_nil?: false
      run Actions.PostInvoice
    end

    action :post_payment, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :payment_id, :uuid, allow_nil?: false
      run Actions.PostPayment
    end

    action :post_bill, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :bill_id, :uuid, allow_nil?: false
      run Actions.PostBill
    end

    action :post_bill_payment, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :bill_payment_id, :uuid, allow_nil?: false
      run Actions.PostBillPayment
    end

    action :post_stock_operation, :struct do
      description "Values a stock operation; returns nil when there is nothing to post."
      constraints instance_of: Zippiker.Accounting.JournalEntry
      allow_nil? true
      argument :operation_id, :uuid, allow_nil?: false
      run Actions.PostStockOperation
    end

    action :post_expense_claim, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :claim_id, :uuid, allow_nil?: false
      run Actions.PostExpenseClaim
    end

    action :post_expense_reimbursement, :struct do
      constraints instance_of: Zippiker.Accounting.JournalEntry
      argument :claim_id, :uuid, allow_nil?: false
      run Actions.PostExpenseReimbursement
    end

    action :reverse_source do
      description "Reverses the entry posted for a document, if any."

      argument :source, :atom,
        allow_nil?: false,
        constraints: [
          one_of: [
            :invoice,
            :payment,
            :bill,
            :bill_payment,
            :stock,
            :expense_claim,
            :expense_reimbursement,
            :production
          ]
        ]

      argument :source_id, :uuid, allow_nil?: false
      run Actions.ReverseSource
    end
  end
end
