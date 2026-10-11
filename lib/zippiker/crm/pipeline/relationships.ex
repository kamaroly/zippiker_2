defmodule Zippiker.Crm.Pipeline.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :stages, Zippiker.Crm.Stage do
      public? true
      sort position: :asc
    end
  end
end
