defmodule Zippiker.Purchasing.Bill.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Purchasing.Bill.Changes, as: BillChanges
  alias Zippiker.Purchasing.Changes, as: PurchasingChanges
  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.Validations.InStatus

  @fields [:branch_id, :supplier_id, :supplier_reference, :owner_id, :issued_on, :due_on, :notes]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: [:draft, :open, :paid, :void, :overdue]]
      argument :supplier_id, :uuid
      prepare Zippiker.Purchasing.Bill.Preparations.Search

      prepare build(
                sort: [issued_on: :desc, number: :desc],
                load: [:supplier, :amount_due, :overdue?]
              )

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      change {Zippiker.Accounts.Changes.SetBranch,
              from: [purchase_order_id: Zippiker.Purchasing.PurchaseOrder]}

      primary? true
      accept [:legal_entity_id, :purchase_order_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :bill, prefix: "BILL"}
      change PurchasingChanges.MarkSupplier
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    create :from_purchase_order do
      change {Zippiker.Accounts.Changes.SetBranch,
              from: [purchase_order_id: Zippiker.Purchasing.PurchaseOrder]}

      description "A draft bill copying a purchase order's supplier and lines."
      argument :purchase_order_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change BillChanges.CopyPurchaseOrder
      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :bill, prefix: "BILL"}
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft], message: "approved bills can't be edited; void them instead"}

      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :set_totals do
      accept [:subtotal, :tax_total, :total]
    end

    update :approve do
      description "Accepts the bill as owed: posts it to the books and makes it payable."
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change BillChanges.Approve
      change BillChanges.ReceiveUnorderedStock
      change {PurchasingChanges.PostToLedger, event: :bill_approved}
    end

    update :apply_payments do
      require_atomic? false
      change BillChanges.ApplyPayments
    end

    update :void do
      require_atomic? false
      validate {InStatus, statuses: [:open], message: "only unpaid approved bills can be voided"}
      validate Zippiker.Sales.Invoice.Validations.NoPayments
      change set_attribute(:status, :void)
      change set_attribute(:voided_at, &DateTime.utc_now/0)
      change {PurchasingChanges.PostToLedger, event: :bill_voided}
      change BillChanges.ReturnUnorderedStock
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate {InStatus,
                statuses: [:draft], message: "only drafts can be deleted; void approved bills"}
    end
  end
end
