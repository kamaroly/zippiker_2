defmodule Zippiker.Reporting.Catalog do
  @moduledoc """
  Every standard report: its key (the URL slug), title, the groups it is
  listed under, the modules it needs, what period it takes and the function
  that builds it.

  Periods: `:range` (from–to), `:as_of` (one date) or `:none` (a list).
  """

  alias Zippiker.Reporting.Reports.{
    Audit,
    Contacts,
    Financial,
    Inventory,
    Ledger,
    Payables,
    Receivables,
    Sales,
    Tax,
    Time
  }

  @groups [
    {:overview, "Business overview"},
    {:receivables, "Who owes you"},
    {:sales, "Sales and customers"},
    {:payables, "What you owe"},
    {:inventory, "Inventory and orders"},
    {:tax, "Sales tax"},
    {:employees, "Employees"},
    {:accountant, "For my accountant"}
  ]

  # {key, title, groups, modules, period, {module, function}, description}
  @reports [
    # Business overview
    {"audit-log", "Audit log", [:overview], [], :range, {Audit, :audit_log},
     "Who created, changed or deleted which record, and when."},
    {"balance-sheet", "Balance sheet", [:overview, :accountant], [:accounting], :as_of,
     {Financial, :balance_sheet}, "What you own, what you owe and equity on a date."},
    {"balance-sheet-comparison", "Balance sheet comparison", [:overview, :accountant],
     [:accounting], :as_of, {Financial, :balance_sheet_comparison},
     "The balance sheet on a date next to the same date a year earlier."},
    {"balance-sheet-detail", "Balance sheet detail", [:overview, :accountant], [:accounting],
     :as_of, {Financial, :balance_sheet_detail},
     "Every posting behind each balance sheet account."},
    {"balance-sheet-summary", "Balance sheet summary", [:overview, :accountant], [:accounting],
     :as_of, {Financial, :balance_sheet_summary},
     "Assets, liabilities and equity by category, without account detail."},
    {"statement-of-cash-flows", "Statement of cash flows", [:overview, :accountant],
     [:accounting], :range, {Financial, :cash_flows},
     "How cash moved through operating, investing and financing activities."},
    {"business-snapshot", "Business snapshot", [:overview], [:accounting], :range,
     {Financial, :business_snapshot},
     "Income, expenses, top customers and expenses, and what is owed, on one page."},
    {"statement-of-changes-in-equity", "Statement of changes in equity", [:overview],
     [:accounting], :range, {Financial, :changes_in_equity},
     "Opening equity, profit for the period, other movements and closing equity."},
    {"profit-and-loss", "Profit and loss", [:overview, :accountant], [:accounting], :range,
     {Financial, :profit_and_loss}, "Income minus expenses over a period."},
    {"profit-and-loss-by-customer", "Profit and loss by customer", [:overview], [:sales], :range,
     {Sales, :profit_and_loss_by_customer},
     "Sales, cost of sales and gross profit for each customer."},
    {"profit-and-loss-by-month", "Profit and loss by month", [:overview, :accountant],
     [:accounting], :range, {Financial, :profit_and_loss_by_month},
     "Profit and loss with a column per month."},
    {"profit-and-loss-by-tag-group", "Profit and loss by tag group", [:overview], [:sales],
     :range, {Sales, :profit_and_loss_by_tag}, "Sales, purchases and net for each contact tag."},
    {"profit-and-loss-comparison", "Profit and loss comparison", [:overview, :accountant],
     [:accounting], :range, {Financial, :profit_and_loss_comparison},
     "This period next to the same period a year earlier."},
    {"profit-and-loss-detail", "Profit and loss detail", [:overview], [:accounting], :range,
     {Financial, :profit_and_loss_detail},
     "Every posting behind each income and expense account."},
    {"profit-and-loss-percent-of-income", "Profit and loss as % of total income",
     [:overview, :accountant], [:accounting], :range, {Financial, :profit_and_loss_percent},
     "Each line of the profit and loss as a share of total income."},
    {"profit-and-loss-ytd-comparison", "Profit and loss year-to-date comparison",
     [:overview, :accountant], [:accounting], :range, {Financial, :profit_and_loss_ytd},
     "The period next to the year to date."},
    {"project-profitability-summary", "Project profitability summary", [:overview],
     [:crm, :sales], :range, {Sales, :project_profitability},
     "Income, cost and profit of each deal (project)."},
    {"quarterly-profit-and-loss-summary", "Quarterly profit and loss summary",
     [:overview, :accountant], [:accounting], :range, {Financial, :profit_and_loss_by_quarter},
     "Profit and loss with a column per quarter."},

    # Who owes you
    {"ar-ageing-summary", "Accounts receivable ageing summary", [:receivables], [:sales], :as_of,
     {Receivables, :ageing_summary}, "What each customer owes, by how overdue it is."},
    {"ar-ageing-detail", "Accounts receivable ageing detail", [:receivables], [:sales], :as_of,
     {Receivables, :ageing_detail}, "Each unpaid invoice, grouped by how overdue it is."},
    {"collections", "Collections report", [:receivables], [:sales], :as_of,
     {Receivables, :collections}, "Overdue invoices with the customer's phone and email."},
    {"customer-balance-summary", "Customer balance summary", [:receivables], [:sales], :as_of,
     {Receivables, :balance_summary}, "What each customer owes on a date."},
    {"customer-balance-detail", "Customer balance detail", [:receivables], [:sales], :as_of,
     {Receivables, :balance_detail}, "Each customer's open invoices with a running balance."},
    {"invoice-list", "Invoice list", [:receivables], [:sales], :range,
     {Receivables, :invoice_list}, "Every invoice issued in the period."},
    {"invoices-and-received-payments", "Invoices and received payments", [:receivables], [:sales],
     :range, {Receivables, :invoices_and_payments},
     "Each invoice with the payments received against it."},
    {"open-invoices", "Open invoices", [:receivables], [:sales], :as_of,
     {Receivables, :open_invoices}, "Invoices not fully paid on a date, by customer."},
    {"statement-list", "Statement list", [:receivables], [:sales], :range,
     {Receivables, :statement_list},
     "A statement line per customer: opening balance, invoiced, received, closing."},
    {"terms-list", "Terms list", [:receivables, :payables], [:sales], :none,
     {Receivables, :terms_list}, "Payment terms in use on invoices and bills."},
    {"unbilled-charges", "Unbilled charges", [:receivables], [:sales], :none,
     {Receivables, :unbilled_charges},
     "Goods delivered on sales orders that are not invoiced yet."},
    {"unbilled-time", "Unbilled time", [:receivables, :employees], [:hr], :range,
     {Time, :unbilled_time}, "Billable time not invoiced yet."},

    # Sales and customers
    {"cashflow-payment-transactions", "Cashflow payment transactions", [:sales], [:sales], :range,
     {Sales, :payment_transactions}, "Money received and paid, by date."},
    {"sales-by-customer-type-detail", "Sales by customer type detail", [:sales], [:sales], :range,
     {Sales, :sales_by_customer_type}, "Invoice lines grouped by the customer's industry."},
    {"customer-contact-list", "Customer contact list", [:sales], [], :none,
     {Contacts, :customer_contacts}, "Customers with email, phone and address."},
    {"income-by-customer-summary", "Income by customer summary", [:sales], [:sales], :range,
     {Sales, :income_by_customer}, "Income, expenses and net income for each customer."},
    {"customer-phone-list", "Customer phone list", [:sales], [], :none,
     {Contacts, :customer_phones}, "Customers and their phone numbers."},
    {"sales-by-customer-summary", "Sales by customer summary", [:sales], [:sales], :range,
     {Sales, :sales_by_customer_summary}, "Sales for each customer."},
    {"sales-by-customer-detail", "Sales by customer detail", [:sales], [:sales], :range,
     {Sales, :sales_by_customer_detail}, "Every invoice line, grouped by customer."},
    {"deposit-detail", "Deposit detail", [:sales], [:sales], :range, {Sales, :deposit_detail},
     "Payments received, grouped by where the money went."},
    {"estimates-by-customer", "Estimates by customer", [:sales], [:sales], :range,
     {Sales, :estimates_by_customer}, "Quotes issued, grouped by customer."},
    {"product-service-list", "Product/service list", [:sales, :inventory], [:sales], :none,
     {Sales, :product_list}, "Every product and service with prices and stock."},
    {"sales-by-product-summary", "Sales by product/service summary", [:sales], [:sales], :range,
     {Sales, :sales_by_product_summary}, "Quantity, sales and margin for each product."},
    {"sales-by-product-detail", "Sales by product/service detail", [:sales], [:sales], :range,
     {Sales, :sales_by_product_detail}, "Every invoice line, grouped by product."},
    {"payment-method-list", "Payment method list", [:sales], [:sales], :range,
     {Sales, :payment_methods}, "How you were paid and how you paid, by method."},
    {"time-activities-by-customer-detail", "Time activities by customer detail", [:sales], [:hr],
     :range, {Time, :by_customer}, "Time logged for each customer."},
    {"transaction-list-by-customer", "Transaction list by customer", [:sales], [:sales], :range,
     {Sales, :transactions_by_customer},
     "Quotes, orders, deliveries, invoices and payments by customer."},
    {"transaction-list-by-tag-group", "Transaction list by tag group", [:sales], [:sales], :range,
     {Sales, :transactions_by_tag}, "Invoices, payments and bills by contact tag."},

    # What you owe
    {"ap-ageing-summary", "Accounts payable ageing summary", [:payables], [:purchasing], :as_of,
     {Payables, :ageing_summary}, "What you owe each supplier, by how overdue it is."},
    {"ap-ageing-detail", "Accounts payable ageing detail", [:payables], [:purchasing], :as_of,
     {Payables, :ageing_detail}, "Each unpaid bill, grouped by how overdue it is."},
    {"bills-and-applied-payments", "Bills and applied payments", [:payables], [:purchasing],
     :range, {Payables, :bills_and_payments}, "Each bill with the payments made against it."},
    {"bill-payment-list", "Bill payment list", [:payables], [:purchasing], :range,
     {Payables, :bill_payments}, "Every payment made to suppliers."},
    {"unpaid-bills", "Unpaid bills", [:payables], [:purchasing], :as_of,
     {Payables, :unpaid_bills}, "Bills not fully paid on a date, by supplier."},
    {"vendor-balance-summary", "Supplier balance summary", [:payables], [:purchasing], :as_of,
     {Payables, :balance_summary}, "What you owe each supplier on a date."},
    {"vendor-balance-detail", "Supplier balance detail", [:payables], [:purchasing], :as_of,
     {Payables, :balance_detail}, "Each supplier's open bills with a running balance."},
    {"cheque-detail", "Cheque detail", [:payables], [:purchasing], :range,
     {Payables, :cheque_detail}, "Supplier payments made by cheque."},
    {"purchases-by-product-detail", "Purchases by product/service detail", [:payables],
     [:purchasing], :range, {Payables, :purchases_by_product},
     "Every bill line, grouped by product."},
    {"purchase-list", "Purchase list", [:payables], [:purchasing], :range,
     {Payables, :purchase_list}, "Purchase orders and bills in the period."},
    {"transaction-list-by-vendor", "Transaction list by supplier", [:payables], [:purchasing],
     :range, {Payables, :transactions_by_supplier},
     "Requests for quotation, orders, receipts, bills and payments by supplier."},
    {"purchases-by-vendor-detail", "Purchases by supplier detail", [:payables], [:purchasing],
     :range, {Payables, :purchases_by_supplier}, "Every bill line, grouped by supplier."},
    {"vendor-contact-list", "Supplier contact list", [:payables], [], :none,
     {Contacts, :supplier_contacts}, "Suppliers with email, phone and address."},
    {"expenses-by-vendor-summary", "Expenses by supplier summary", [:payables], [:purchasing],
     :range, {Payables, :expenses_by_supplier},
     "Spending per supplier, including expense claim merchants."},
    {"vendor-phone-list", "Supplier phone list", [:payables], [], :none,
     {Contacts, :supplier_phones}, "Suppliers and their phone numbers."},

    # Inventory and orders
    {"inventory-valuation-detail", "Inventory valuation detail", [:inventory], [:inventory],
     :range, {Inventory, :valuation_detail},
     "Every stock movement with running quantity and value."},
    {"inventory-valuation-summary", "Inventory valuation summary", [:inventory], [:inventory],
     :as_of, {Inventory, :valuation_summary},
     "Quantity, average cost and value of each product."},
    {"open-purchase-order-detail", "Open purchase order detail", [:inventory, :payables],
     [:purchasing], :none, {Inventory, :open_purchase_order_detail},
     "Lines still to be received, by supplier."},
    {"open-purchase-order-list", "Open purchase order list", [:inventory, :payables],
     [:purchasing], :none, {Inventory, :open_purchase_order_list},
     "Purchase orders not fully received."},
    {"physical-inventory-worksheet", "Physical inventory worksheet", [:inventory], [:inventory],
     :none, {Inventory, :physical_worksheet},
     "A count sheet: system quantity and a blank to fill."},
    {"inventory-status", "Inventory status", [:inventory], [:inventory], :none,
     {Inventory, :status}, "On hand, on order, committed to customers and available."},
    {"open-sales-orders-by-customer", "Open sales orders by customer", [:inventory, :sales],
     [:sales], :none, {Inventory, :open_sales_orders_by_customer},
     "Lines still to be delivered, by customer."},
    {"open-sales-orders-by-item", "Open sales orders by item", [:inventory, :sales], [:sales],
     :none, {Inventory, :open_sales_orders_by_item}, "Lines still to be delivered, by product."},
    {"sales-order-list", "Sales order list", [:inventory, :sales], [:sales], :range,
     {Inventory, :sales_order_list}, "Every sales order in the period."},

    # Sales tax
    {"vat-detail", "VAT detail report", [:tax], [:sales], :range, {Tax, :detail},
     "Every taxed sale and purchase line, by tax rate."},
    {"vat-exception", "VAT exception report", [:tax], [:sales], :range, {Tax, :exceptions},
     "Lines whose tax doesn't match their tax code or product."},
    {"vat-summary", "VAT summary report", [:tax], [:sales], :range, {Tax, :summary},
     "Output and input VAT per tax rate, and the net."},
    {"tax-liability", "Tax liability report", [:tax], [:accounting], :range, {Tax, :liability},
     "Tax collected, tax paid and what is due, from the ledger."},
    {"transaction-detail-by-tax-code", "Transaction detail by tax code", [:tax], [:sales], :range,
     {Tax, :by_tax_code}, "Sales and purchase lines under each tax code."},

    # Employees
    {"employee-contact-list", "Employee contact list", [:employees], [:hr], :none,
     {Contacts, :employee_contacts}, "Employees with job, department and contact details."},
    {"recent-edited-time-activities", "Recent/edited time activities", [:employees], [:hr],
     :range, {Time, :recent}, "Time entries created or changed in the period."},
    {"time-activities-by-employee-detail", "Time activities by employee detail", [:employees],
     [:hr], :range, {Time, :by_employee}, "Time logged by each employee."},
    {"timesheet-detail-by-employee", "Timesheet detail by employee", [:employees], [:hr], :range,
     {Time, :timesheets}, "Daily hours for each employee with totals."},
    {"time-summary-by-pay-type", "Time summary by pay type", [:employees], [:hr], :range,
     {Time, :by_pay_type}, "Hours per employee by pay type."},

    # For my accountant
    {"account-list", "Account list", [:accountant], [:accounting], :as_of,
     {Ledger, :account_list}, "The chart of accounts with balances."},
    {"invalid-journal-transactions", "Invalid journal transactions", [:accountant], [:accounting],
     :range, {Ledger, :invalid_transactions},
     "Entries that don't balance or use inactive accounts."},
    {"general-ledger", "General ledger", [:accountant], [:accounting], :range,
     {Ledger, :general_ledger},
     "Every account with opening balance, postings and closing balance."},
    {"general-ledger-list", "General ledger list", [:accountant], [:accounting], :range,
     {Ledger, :general_ledger_list}, "Opening, debits, credits and closing for each account."},
    {"journal", "Journal", [:accountant], [:accounting], :range, {Ledger, :journal},
     "Every journal entry with its debit and credit lines."},
    {"recent-transactions", "Recent transactions", [:accountant], [:accounting], :range,
     {Ledger, :recent_transactions}, "Journal entries posted most recently."},
    {"trial-balance", "Trial balance", [:accountant], [:accounting], :as_of,
     {Ledger, :trial_balance}, "Debit and credit balance of every account on a date."},
    {"adjusted-trial-balance", "Adjusted trial balance", [:accountant], [:accounting], :as_of,
     {Ledger, :adjusted_trial_balance},
     "The trial balance before and after manual journal adjustments."},
    {"transaction-detail-by-account", "Transaction detail by account", [:accountant],
     [:accounting], :range, {Ledger, :transactions_by_account},
     "Postings grouped by account with a running balance."},
    {"transaction-list-by-date", "Transaction list by date", [:accountant], [:accounting], :range,
     {Ledger, :transactions_by_date}, "Journal entries in date order."},
    {"transaction-list-with-splits", "Transaction list with splits", [:accountant], [:accounting],
     :range, {Ledger, :transactions_with_splits},
     "Each journal entry with every account it touched."}
  ]

  @doc "Group keys and labels, in display order."
  def groups, do: @groups

  @doc "Every report as a map."
  def all, do: Enum.map(@reports, &to_map/1)

  @doc "The reports a workspace can run (all their modules enabled)."
  def available(organization) do
    enabled = organization.enabled_modules || []
    Enum.filter(all(), fn report -> Enum.all?(report.modules, &(&1 in enabled)) end)
  end

  @doc "A report by key, or nil."
  def get(key), do: Enum.find(all(), &(&1.key == key))

  defp to_map({key, title, groups, modules, period, run, description}) do
    %{
      key: key,
      title: title,
      groups: groups,
      modules: modules,
      period: period,
      run: run,
      description: description
    }
  end
end
