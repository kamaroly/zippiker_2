defmodule Zippiker.Crm.Pipeline do
  @moduledoc "An ordered set of stages deals move through."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Crm.Pipeline.Attributes,
      Zippiker.Crm.Pipeline.Relationships,
      Zippiker.Crm.Pipeline.Actions,
      Zippiker.Crm.Pipeline.Policies
    ]

  postgres do
    table "pipelines"
    repo Zippiker.Repo
  end

  multitenancy do
    strategy :context
  end
end
