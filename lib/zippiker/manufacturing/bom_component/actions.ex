defmodule Zippiker.Manufacturing.BomComponent.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:bom_id, :product_id, :quantity, :position]
    end

    update :update do
      primary? true
      accept [:product_id, :quantity, :position]
    end
  end
end
