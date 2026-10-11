defmodule Zippiker.Manufacturing.BomOperation.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :bom, Zippiker.Manufacturing.BillOfMaterials, allow_nil?: false, public?: true
    belongs_to :work_center, Zippiker.Manufacturing.WorkCenter, allow_nil?: false, public?: true
  end
end
