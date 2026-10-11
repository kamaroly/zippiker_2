defmodule Zippiker.Crm.Stage.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :pipeline, Zippiker.Crm.Pipeline do
      allow_nil? false
      public? true
    end

    has_many :deals, Zippiker.Crm.Deal do
      public? true
    end
  end
end
