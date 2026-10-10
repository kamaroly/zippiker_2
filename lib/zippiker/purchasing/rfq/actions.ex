defmodule Zippiker.Purchasing.Rfq.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Purchasing.Changes.MarkSupplier
  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.Validations.InStatus

  @fields [:supplier_id, :owner_id, :issued_on, :valid_until, :supplier_reference, :notes]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string

      argument :status, :atom,
        constraints: [one_of: [:draft, :sent, :quoted, :accepted, :declined]]

      argument :supplier_id, :uuid
      prepare Zippiker.Purchasing.Rfq.Preparations.Search
      prepare build(sort: [issued_on: :desc, number: :desc], load: [:supplier, :purchase_order])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept [:legal_entity_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :rfq, prefix: "RFQ"}
      change MarkSupplier
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft, :sent, :quoted],
                message: "accepted or declined requests can't be edited"}

      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :set_totals do
      accept [:subtotal, :tax_total, :total]
    end

    update :mark_sent do
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change set_attribute(:status, :sent)
    end

    update :mark_quoted do
      description "The supplier replied; their prices are on the lines."
      require_atomic? false
      validate {InStatus, statuses: [:draft, :sent]}
      change set_attribute(:status, :quoted)
    end

    update :accept do
      require_atomic? false
      validate {InStatus, statuses: [:draft, :sent, :quoted]}
      change set_attribute(:status, :accepted)
    end

    update :decline do
      require_atomic? false
      validate {InStatus, statuses: [:draft, :sent, :quoted]}
      change set_attribute(:status, :declined)
    end

    update :reopen do
      require_atomic? false
      validate {InStatus, statuses: [:sent, :quoted, :declined]}
      change set_attribute(:status, :draft)
    end
  end
end
