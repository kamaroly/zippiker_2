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

    references do
      reference :organization, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
