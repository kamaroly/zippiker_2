defmodule Zippiker.HR.Employee.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :direct_reports_count, :direct_reports, public?: true

    exists :on_leave_today?, :leave_requests do
      public? true
      filter expr(status == :approved and start_date <= today() and end_date >= today())
    end
  end
end
