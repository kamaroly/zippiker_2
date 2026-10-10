defmodule Zippiker.Sales.Delivery.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Validations.InStatus

  actions do
    defaults [:read]

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: [:shipped, :delivered, :cancelled]]
      argument :sales_order_id, :uuid
      argument :invoice_id, :uuid
      prepare Zippiker.Sales.Delivery.Preparations.Search

      prepare build(
                sort: [shipped_on: :desc, number: :desc],
                load: [:customer, :sales_order, :invoice, :warehouse]
              )

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :record do
      description "Written when an order is delivered or an invoice ships goods."

      accept [
        :shipped_on,
        :carrier,
        :tracking_number,
        :notes,
        :legal_entity_id,
        :customer_id,
        :sales_order_id,
        :invoice_id,
        :warehouse_id,
        :stock_operation_id
      ]

      argument :lines, {:array, :map}, default: []

      change relate_actor(:shipped_by, allow_nil?: true)
      change set_new_attribute(:shipped_on, &Date.utc_today/0)
      change manage_relationship(:lines, type: :create)
      change {Zippiker.Sales.Changes.AssignNumber, document_type: :delivery, prefix: "DN"}
    end

    update :confirm do
      description "The customer signed for the goods."
      require_atomic? false
      accept [:received_by_name, :delivered_on]

      validate {InStatus,
                statuses: [:shipped], message: "only shipped deliveries can be confirmed"}

      change set_attribute(:status, :delivered)
      change set_new_attribute(:delivered_on, &Date.utc_today/0)
    end

    update :update do
      description "Carrier, tracking and notes can be corrected after shipping."
      primary? true
      accept [:carrier, :tracking_number, :notes]
    end

    update :cancel do
      description "Set when the invoice that shipped the goods is voided."
      change set_attribute(:status, :cancelled)
    end
  end
end
