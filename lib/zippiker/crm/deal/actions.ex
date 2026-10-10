defmodule Zippiker.Crm.Deal.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Crm.Deal.{Changes, Preparations, Validations}

  @fields [
    :title,
    :amount,
    :stage_id,
    :expected_close_on,
    :lost_reason,
    :description,
    :party_id,
    :company_id,
    :owner_id,
    :lead_id,
    :custom_fields
  ]

  actions do
    defaults [:read, :destroy]

    read :search do
      argument :query, :string
      argument :status, :atom, constraints: [one_of: [:open, :won, :lost]]
      argument :party_id, :uuid
      argument :owner_id, :uuid
      argument :custom_fields, :map

      prepare Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [inserted_at: :desc], load: [:stage, :party, :company, :owner])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    read :board do
      description "Deals for a pipeline board: every open deal plus deals closed in the last 30 days."
      argument :pipeline_id, :uuid, allow_nil?: false

      filter expr(
               pipeline_id == ^arg(:pipeline_id) and
                 (status == :open or closed_at > ago(30, :day))
             )

      prepare build(sort: [position: :asc], load: [:party, :company, :owner, :overdue?])
    end

    create :create do
      primary? true
      accept @fields
      change Changes.SyncStage
      change Changes.PlaceOnTop
      validate Validations.AmountInBaseCurrency
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      change Changes.SyncStage
      validate Validations.AmountInBaseCurrency
    end

    update :move do
      description "Drag & drop on the board: change stage and/or position."
      accept [:stage_id, :position]
      require_atomic? false
      change Changes.SyncStage
    end
  end
end
