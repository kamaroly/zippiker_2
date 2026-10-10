defmodule Zippiker.Sales.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    action :summary, :map do
      description "Receivables, overdue, invoiced and collected this month, open quotes."
      run Zippiker.Sales.Reports.Actions.Summary
    end
  end
end
