defmodule Zippiker.Sales.Quote.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Sales.Changes
  alias Zippiker.Sales.Validations.InStatus

  @fields [
    :branch_id,
    :customer_id,
    :contact_id,
    :deal_id,
    :owner_id,
    :issued_on,
    :valid_until,
    :notes,
    :custom_fields
  ]

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false

      validate {InStatus,
                statuses: [:draft, :declined],
                message: "only draft or declined quotes can be archived"}
    end

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: [:draft, :sent, :accepted, :declined]]
      argument :customer_id, :uuid
      argument :deal_id, :uuid
      argument :custom_fields, :map

      prepare Zippiker.Sales.Quote.Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [issued_on: :desc, number: :desc], load: [:customer])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      change Zippiker.Accounts.Changes.SetBranch
      primary? true
      accept [:legal_entity_id | @fields]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change Changes.DefaultOwner
      change {Changes.AssignNumber, document_type: :quote}
      change manage_relationship(:lines, type: :direct_control)
      change Changes.ComputeTotals
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      argument :lines, {:array, :map}

      validate {InStatus,
                statuses: [:draft, :sent], message: "accepted or declined quotes can't be edited"}

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

    update :accept do
      require_atomic? false
      validate {InStatus, statuses: [:draft, :sent]}
      change set_attribute(:status, :accepted)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
      change Zippiker.Sales.Quote.Changes.WinDeal
    end

    update :decline do
      require_atomic? false
      validate {InStatus, statuses: [:draft, :sent]}
      change set_attribute(:status, :declined)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
    end

    update :reopen do
      description "Back to draft, e.g. to revise a declined quote."
      require_atomic? false
      validate {InStatus, statuses: [:sent, :declined]}
      change set_attribute(:status, :draft)
      change set_attribute(:decided_at, nil)
    end
  end
end
