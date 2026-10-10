defmodule Zippiker.Purchasing.RfqLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :rfq, Zippiker.Purchasing.Rfq, allow_nil?: false, public?: true
  end
end
