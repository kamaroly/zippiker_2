defmodule Zippiker.Crm.Dashboard.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    action :summary, :map do
      description "Headline numbers, pipeline funnel, revenue trend and the actor's agenda."
      run Zippiker.Crm.Dashboard.Actions.Summary
    end
  end
end
