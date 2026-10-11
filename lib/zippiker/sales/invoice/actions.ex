defmodule Zippiker.Sales.Invoice.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.Invoice.Changes, as: InvoiceChanges
  alias Zippiker.Sales.Validations.InStatus

  @fields [
    :branch_id,
    :customer_id,
    :contact_id,
    :deal_id,
    :owner_id,
    :issued_on,
    :due_on,
    :notes,
    :custom_fields
  ]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: [:draft, :issued, :paid, :void, :overdue]]
      argument :customer_id, :uuid
      argument :deal_id, :uuid
      argument :custom_fields, :map

      prepare Zippiker.Sales.Invoice.Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [inserted_at: :desc], load: [:customer, :amount_due, :overdue?])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      change {Zippiker.Accounts.Changes.SetBranch,
              from: [sales_order_id: Zippiker.Sales.SalesOrder, quote_id: Zippiker.Sales.Quote]}

      primary? true
      accept [:legal_entity_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    create :from_quote do
      change {Zippiker.Accounts.Changes.SetBranch,
              from: [sales_order_id: Zippiker.Sales.SalesOrder, quote_id: Zippiker.Sales.Quote]}

      description "A draft invoice copying the quote's customer and lines."
      argument :quote_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change InvoiceChanges.CopyQuote
      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
      change Changes.AcceptSourceQuote
    end

    create :from_sales_order do
      change {Zippiker.Accounts.Changes.SetBranch,
              from: [sales_order_id: Zippiker.Sales.SalesOrder, quote_id: Zippiker.Sales.Quote]}

      description "A draft invoice copying a sales order's customer and lines."
      argument :sales_order_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change InvoiceChanges.CopySalesOrder
      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft],
                message: "issued invoices can't be edited; void and re-issue instead"}

      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :set_totals do
      accept [:subtotal, :tax_total, :total]
    end

    update :issue do
      description "Numbers the invoice and makes it payable."
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change InvoiceChanges.Issue
      change {Changes.AssignNumber, document_type: :invoice}
      change {Changes.PostToLedger, event: :invoice_issued}
      change InvoiceChanges.ShipGoods
    end

    update :apply_payments do
      description "Recomputes amount paid and paid status from payments."
      require_atomic? false
      change InvoiceChanges.ApplyPayments
    end

    update :void do
      require_atomic? false

      validate {InStatus,
                statuses: [:issued], message: "only unpaid issued invoices can be voided"}

      validate {Zippiker.Sales.Invoice.Validations.NoPayments, []}
      change set_attribute(:status, :void)
      change set_attribute(:voided_at, &DateTime.utc_now/0)
      change {Changes.PostToLedger, event: :invoice_voided}
      change InvoiceChanges.ReturnGoods
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate {InStatus,
                statuses: [:draft], message: "only drafts can be deleted; void issued invoices"}
    end
  end
end
