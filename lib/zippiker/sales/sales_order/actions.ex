defmodule Zippiker.Sales.SalesOrder.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.SalesOrder.Changes, as: OrderChanges
  alias Zippiker.Sales.Validations.InStatus

  @fields [
    :customer_id,
    :contact_id,
    :deal_id,
    :warehouse_id,
    :owner_id,
    :issued_on,
    :expected_on,
    :notes
  ]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string

      argument :status, :atom,
        constraints: [one_of: [:draft, :confirmed, :partially_delivered, :delivered, :cancelled]]

      argument :customer_id, :uuid
      argument :deal_id, :uuid
      prepare Zippiker.Sales.SalesOrder.Preparations.Search
      prepare build(sort: [issued_on: :desc, number: :desc], load: [:customer, :invoice])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept [:legal_entity_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :sales_order, prefix: "SO"}
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    create :from_quote do
      description "A draft order copying a quote (accepting it if it was still open)."
      argument :quote_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change OrderChanges.CopyQuote
      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :sales_order, prefix: "SO"}
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
      change Changes.AcceptSourceQuote
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft, :confirmed],
                message: "orders can't be edited once delivery has started"}

      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :set_totals do
      accept [:subtotal, :tax_total, :total]
    end

    update :confirm do
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change set_attribute(:status, :confirmed)
    end

    update :deliver do
      description "Ships goods. `quantities` maps line id → quantity; omit to deliver everything left."
      require_atomic? false
      argument :quantities, :map
      argument :date, :date
      argument :carrier, :string, constraints: [max_length: 120]
      argument :tracking_number, :string, constraints: [max_length: 120]

      validate {InStatus,
                statuses: [:confirmed, :partially_delivered],
                message: "confirm the order before delivering"}

      change OrderChanges.Deliver
    end

    update :mark_delivered do
      description "Set when the order's invoice shipped what was left."
      require_atomic? false
      change OrderChanges.MarkAllDelivered
    end

    update :cancel do
      require_atomic? false

      validate {InStatus,
                statuses: [:draft, :confirmed], message: "delivered orders can't be cancelled"}

      change set_attribute(:status, :cancelled)
    end
  end
end
