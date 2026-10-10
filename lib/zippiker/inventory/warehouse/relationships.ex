defmodule Zippiker.Inventory.Warehouse.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    has_many :movements, Zippiker.Inventory.StockMovement
  end
end
