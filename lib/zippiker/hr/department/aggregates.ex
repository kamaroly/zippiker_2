defmodule Zippiker.HR.Department.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :headcount, :employees do
      public? true
      filter expr(status == :active)
    end
  end
end
