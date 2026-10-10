defmodule Zippiker.Sales.QuoteLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :quote, Zippiker.Sales.Quote, allow_nil?: false, public?: true
  end
end
