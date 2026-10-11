defmodule Zippiker.Manufacturing.WorkCenter do
  @moduledoc "A place or team where operations happen (assembly line, paint shop), with its hourly cost."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Manufacturing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Manufacturing.WorkCenter.Attributes,
      Zippiker.Manufacturing.WorkCenter.Relationships,
      Zippiker.Manufacturing.WorkCenter.Actions,
      Zippiker.Manufacturing.WorkCenter.Policies
    ]

  postgres do
    table "work_centers"
    repo Zippiker.Repo
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
  end
end
