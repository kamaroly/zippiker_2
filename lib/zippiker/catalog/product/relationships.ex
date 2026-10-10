defmodule Zippiker.Catalog.Product.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :tax_rate, Zippiker.Catalog.TaxRate, public?: true

    has_many :stock_movements, Zippiker.Inventory.StockMovement do
      domain Zippiker.Inventory
    end
  end
end
