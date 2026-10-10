defmodule Zippiker.Purchasing.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    action :summary, :map do
      description "What we owe suppliers, overdue, due this week, orders still to receive."
      run Zippiker.Purchasing.Reports.Actions.Summary
    end
  end
end
