defmodule Zippiker.Crm.Stage.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :deals_count, :deals do
      public? true
      filter expr(status == :open)
    end

    sum :deals_amount, :deals, :amount do
      public? true
      filter expr(status == :open)
    end
  end
end
