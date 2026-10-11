defmodule Zippiker.Inventory.Warehouse.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :branch, Zippiker.Accounts.Branch do
      public? true
      domain Zippiker.Accounts
    end

    has_many :movements, Zippiker.Inventory.StockMovement
  end
end
