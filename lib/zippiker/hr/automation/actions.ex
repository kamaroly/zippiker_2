defmodule Zippiker.HR.Automation.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.Automation.Actions

  actions do
    action :run_accruals, :map do
      description """
      Credits every accrual period due up to `as_of` (default today) for
      everyone on an accruing policy. Idempotent: each period is credited
      once per employee and policy, so missed runs catch up.
      """

      argument :as_of, :date
      run Actions.RunAccruals
    end

    action :review_overdue, :map do
      description "Approves or rejects pending requests older than their policy's review threshold."
      argument :now, :utc_datetime_usec
      run Actions.ReviewOverdue
    end
  end
end
