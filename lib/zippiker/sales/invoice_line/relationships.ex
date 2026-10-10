defmodule Zippiker.Sales.InvoiceLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :invoice, Zippiker.Sales.Invoice, allow_nil?: false, public?: true
  end
end
