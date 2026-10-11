defmodule Zippiker.Crm.Stage do
  @moduledoc "A step in a pipeline. `kind` tells whether deals in it are open, won or lost."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Crm.Stage.Attributes,
      Zippiker.Crm.Stage.Relationships,
      Zippiker.Crm.Stage.Aggregates,
      Zippiker.Crm.Stage.Actions,
      Zippiker.Crm.Stage.Policies
    ]

  postgres do
    table "stages"
    repo Zippiker.Repo

    references do
      reference :pipeline, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
