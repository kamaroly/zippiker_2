defmodule Zippiker.Platform.Plan.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :code,
    :name,
    :description,
    :price_per_seat,
    :currency,
    :seat_limit,
    :modules,
    :trial_days,
    :default?,
    :active?,
    :position
  ]

  actions do
    defaults [:read]

    read :list do
      argument :active_only?, :boolean, default: false
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [position: :asc, price_per_seat: :asc])
    end

    create :create do
      primary? true
      accept @fields
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
