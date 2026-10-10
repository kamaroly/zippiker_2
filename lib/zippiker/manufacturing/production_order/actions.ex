defmodule Zippiker.Manufacturing.ProductionOrder.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Manufacturing.ProductionOrder.{Changes, Validations}
  alias Zippiker.Sales.Changes, as: SalesChanges
  alias Zippiker.Sales.Validations.InStatus

  @fields [:quantity, :warehouse_id, :planned_start, :due_on, :notes, :owner_id]

  actions do
    defaults [:read]

    read :search do
      argument :query, :string

      argument :status, :atom,
        constraints: [one_of: [:draft, :confirmed, :in_progress, :done, :cancelled, :open]]

      argument :product_id, :uuid
      prepare Zippiker.Manufacturing.ProductionOrder.Preparations.Search

      prepare build(
                sort: [inserted_at: :desc],
                load: [:product, :owner, :remaining_quantity]
              )

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept [:product_id, :bom_id, :legal_entity_id | @fields]

      change Changes.DefaultBom
      validate Validations.BomMatchesProduct
      change SalesChanges.SetLegalEntity
      change SalesChanges.DefaultOwner
      change {SalesChanges.AssignNumber, document_type: :production_order, prefix: "MO"}
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:bom_id | @fields]

      validate {InStatus,
                statuses: [:draft, :confirmed],
                message: "orders can't be changed once production has started"}

      validate Validations.BomMatchesProduct
    end

    update :confirm do
      description "Releases the order to the shop floor."
      require_atomic? false
      validate {InStatus, statuses: [:draft]}
      change set_attribute(:status, :confirmed)
    end

    update :record_output do
      description """
      Records finished units: consumes their components and receives them at
      cost. Completing the planned quantity closes the order.
      """

      require_atomic? false
      argument :quantity, :decimal, allow_nil?: false, constraints: [greater_than: 0]
      argument :date, :date

      validate {InStatus,
                statuses: [:confirmed, :in_progress],
                message: "confirm the order before recording production"}

      change Changes.RecordOutput
    end

    update :finish do
      description "Closes an order that's partly produced (the rest won't be made)."
      require_atomic? false
      validate {InStatus, statuses: [:in_progress]}
      change set_attribute(:status, :done)
      change set_attribute(:finished_at, &DateTime.utc_now/0)
    end

    update :cancel do
      require_atomic? false

      validate {InStatus,
                statuses: [:draft, :confirmed],
                message: "orders with recorded production can be finished, not cancelled"}

      change set_attribute(:status, :cancelled)
    end
  end
end
