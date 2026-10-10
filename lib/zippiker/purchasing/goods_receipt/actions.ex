defmodule Zippiker.Purchasing.GoodsReceipt.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :purchase_order_id, :uuid
      argument :bill_id, :uuid
      prepare Zippiker.Purchasing.GoodsReceipt.Preparations.Search

      prepare build(
                sort: [received_on: :desc, number: :desc],
                load: [:supplier, :purchase_order, :warehouse]
              )

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :record do
      description "Written by receiving a purchase order or approving a bill."

      accept [
        :received_on,
        :supplier_reference,
        :notes,
        :legal_entity_id,
        :supplier_id,
        :purchase_order_id,
        :bill_id,
        :warehouse_id,
        :stock_operation_id
      ]

      argument :lines, {:array, :map}, default: []

      change relate_actor(:received_by, allow_nil?: true)
      change set_new_attribute(:received_on, &Date.utc_today/0)
      change manage_relationship(:lines, type: :create)

      change {Zippiker.Sales.Changes.AssignNumber, document_type: :goods_receipt, prefix: "GRN"}
    end

    update :cancel do
      description "Set when the bill that brought the goods in is voided."
      change set_attribute(:status, :cancelled)
    end
  end
end
