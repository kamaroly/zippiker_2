defmodule Zippiker.Crm.Stage.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :for_pipeline do
      argument :pipeline_id, :uuid, allow_nil?: false
      filter expr(pipeline_id == ^arg(:pipeline_id))
      prepare build(sort: [position: :asc])
    end

    create :create do
      primary? true
      accept [:pipeline_id, :name, :position, :probability, :kind, :color]
    end

    update :update do
      primary? true
      accept [:name, :position, :probability, :color]
    end
  end
end
