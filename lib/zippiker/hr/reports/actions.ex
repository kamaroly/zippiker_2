defmodule Zippiker.HR.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.Reports.Actions

  actions do
    action :summary, :map do
      description "Headcount, new hires (30 days), off today, pending requests, departments."
      run Actions.Summary
    end

    action :balances, {:array, :map} do
      description "Per active leave type: allowance, taken, pending and left for the year."
      argument :employee_id, :uuid, allow_nil?: false
      argument :year, :integer
      run Actions.Balances
    end

    action :org_chart, {:array, :map} do
      description "Active employees as a tree: `%{employee, reports: [...]}`, top level first."
      run Actions.OrgChart
    end
  end
end
