defmodule Zippiker.Compliance.Resolution.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :meeting, Zippiker.Compliance.Meeting, allow_nil?: false, public?: true
  end
end
