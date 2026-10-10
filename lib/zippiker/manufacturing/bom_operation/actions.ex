defmodule Zippiker.Manufacturing.BomOperation.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:name, :work_center_id, :minutes, :instructions, :position]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:bom_id | @fields]
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
