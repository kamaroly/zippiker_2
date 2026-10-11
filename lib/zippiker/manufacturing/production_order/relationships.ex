defmodule Zippiker.Manufacturing.ProductionOrder.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :product, Zippiker.Catalog.Product do
      allow_nil? false
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :bom, Zippiker.Manufacturing.BillOfMaterials, allow_nil?: false, public?: true

    belongs_to :warehouse, Zippiker.Inventory.Warehouse do
      description "Where components are taken from and finished goods go (default warehouse if empty)."
      public? true
      domain Zippiker.Inventory
    end

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
