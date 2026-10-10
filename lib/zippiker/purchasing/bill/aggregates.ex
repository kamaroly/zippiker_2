defmodule Zippiker.Purchasing.Bill.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    sum :payments_total, :payments, :amount, public?: true
  end
end
