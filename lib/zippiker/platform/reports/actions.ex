defmodule Zippiker.Platform.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    action :overview, :map do
      description "Workspaces, users, subscriptions by status, MRR and open platform invoices."
      run Zippiker.Platform.Reports.Actions.Overview
    end
  end
end
