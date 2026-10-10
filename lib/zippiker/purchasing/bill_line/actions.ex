defmodule Zippiker.Purchasing.BillLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :position,
    :description,
    :quantity,
    :unit,
    :unit_price,
    :discount_percent,
    :tax_rate_id,
    :product_id,
    :expense_account_id,
    :received_unit_cost
  ]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept @fields
      change Zippiker.Sales.Changes.PriceLine
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      change Zippiker.Sales.Changes.PriceLine
    end
  end
end
