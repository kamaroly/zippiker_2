defmodule Zippiker.Reporting.Report.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Reporting.Report.Actions

  actions do
    action :catalog, {:array, :map} do
      description "Reports available to this workspace (by enabled modules), in display order."
      run Actions.Catalog
    end

    action :run, :map do
      description """
      Runs one report and returns `%{columns, rows, ...}` – a table any
      screen, print or CSV export can render.
      """

      argument :key, :string, allow_nil?: false
      argument :from, :date, description: "Start of the period (period reports)."
      argument :to, :date, description: "End of the period, or the as-of date."
      argument :branch_id, :uuid, description: "Only this branch (all branches when empty)."
      run Actions.Run
    end
  end
end
