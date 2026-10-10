defmodule Zippiker.HR.LeavePolicy.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :employees_count, :employees do
      public? true
      filter expr(status == :active)
    end
  end
end
