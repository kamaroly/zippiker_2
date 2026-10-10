defmodule Zippiker.Sales.DocumentLine.Actions do
  @moduledoc "Create/update for sales document lines (quotes, orders, invoices)."
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :position,
        :description,
        :quantity,
        :unit,
        :unit_price,
        :discount_percent,
        :tax_rate_id,
        :product_id
      ]

      change Zippiker.Sales.Changes.PriceLine
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :position,
        :description,
        :quantity,
        :unit,
        :unit_price,
        :discount_percent,
        :tax_rate_id,
        :product_id
      ]

      change Zippiker.Sales.Changes.PriceLine
    end
  end
end
