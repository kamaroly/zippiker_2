defmodule Zippiker.Catalog.Product.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :name,
    :sku,
    :description,
    :kind,
    :unit,
    :unit_price,
    :active?,
    :tax_rate_id,
    :custom_fields,
    :track_inventory?,
    :cost_price,
    :reorder_level
  ]

  actions do
    defaults [:read]

    destroy :destroy do
      # Atomic unless maker-checker holds the change (see MakerChecker).
      require_atomic? false
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :products}
      primary? true
    end

    read :search do
      argument :query, :string
      argument :active_only?, :boolean, default: false
      argument :tracked_only?, :boolean, default: false
      argument :custom_fields, :map

      prepare Zippiker.Catalog.Product.Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [name: :asc], load: [:tax_rate, :on_hand, :low_stock?])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :products}
      primary? true
      accept @fields
      validate Zippiker.Catalog.Product.Validations.TrackOnlyGoods
    end

    update :update do
      change {Zippiker.Workflow.Changes.MakerChecker, scope: :products}
      primary? true
      accept @fields
      require_atomic? false
      validate Zippiker.Catalog.Product.Validations.TrackOnlyGoods
    end

    update :set_average_cost do
      description "Inventory keeps the weighted average cost up to date."
      accept [:average_cost]
    end
  end
end
