defmodule Zippiker.Manufacturing.BillOfMaterials.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :product, Zippiker.Catalog.Product do
      allow_nil? false
      public? true
      domain Zippiker.Catalog
    end

    has_many :components, Zippiker.Manufacturing.BomComponent do
      public? true
      destination_attribute :bom_id
      sort position: :asc
    end

    has_many :operations, Zippiker.Manufacturing.BomOperation do
      public? true
      destination_attribute :bom_id
      sort position: :asc
    end
  end
end
