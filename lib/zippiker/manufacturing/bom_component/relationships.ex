defmodule Zippiker.Manufacturing.BomComponent.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :bom, Zippiker.Manufacturing.BillOfMaterials, allow_nil?: false, public?: true

    belongs_to :product, Zippiker.Catalog.Product do
      allow_nil? false
      public? true
      domain Zippiker.Catalog
    end
  end
end
