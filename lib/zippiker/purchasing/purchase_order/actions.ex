defmodule Zippiker.Purchasing.PurchaseOrder.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Purchasing.Changes, as: PurchasingChanges
  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.Validations.InStatus

  @fields [:branch_id, :supplier_id, :warehouse_id, :owner_id, :issued_on, :expected_on, :notes]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string

      argument :status, :atom,
        constraints: [
          one_of: [:draft, :ordered, :partially_received, :received, :cancelled, :open]
        ]

      argument :supplier_id, :uuid
      prepare Zippiker.Purchasing.PurchaseOrder.Preparations.Search
      prepare build(sort: [issued_on: :desc, number: :desc], load: [:supplier])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      change {Zippiker.Accounts.Changes.SetBranch, from: [rfq_id: Zippiker.Purchasing.Rfq]}
      primary? true
      accept [:legal_entity_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :purchase_order, prefix: "PO"}
      change PurchasingChanges.MarkSupplier
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    create :from_rfq do
      change {Zippiker.Accounts.Changes.SetBranch, from: [rfq_id: Zippiker.Purchasing.Rfq]}
      description "A draft purchase order from a supplier's quotation; accepts the request."
      argument :rfq_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change Zippiker.Purchasing.PurchaseOrder.Changes.CopyRfq
      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :purchase_order, prefix: "PO"}
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft, :ordered],
                message: "received or cancelled orders can't be edited"}

      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :set_totals do
      accept [:subtotal, :tax_total, :total]
    end

    update :mark_ordered do
      description "Sent to the supplier."
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change set_attribute(:status, :ordered)
    end

    update :receive do
      description "Brings goods in. `quantities` maps line id → quantity; omit to receive everything left."
      require_atomic? false
      argument :quantities, :map
      argument :date, :date
      argument :warehouse_id, :uuid
      argument :reference, :string, constraints: [max_length: 120]

      validate {InStatus,
                statuses: [:ordered, :partially_received],
                message: "place the order before receiving it"}

      change Zippiker.Purchasing.PurchaseOrder.Changes.Receive
    end

    update :acknowledge do
      description "The supplier confirms they received the order."
      validate attribute_does_not_equal(:status, :draft), message: "not sent to the supplier yet"
      change set_attribute(:acknowledged_at, &DateTime.utc_now/0)
    end

    update :cancel do
      require_atomic? false

      validate {InStatus,
                statuses: [:draft, :ordered], message: "received orders can't be cancelled"}

      change set_attribute(:status, :cancelled)
    end
  end
end
