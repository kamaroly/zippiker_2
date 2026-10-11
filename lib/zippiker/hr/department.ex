defmodule Zippiker.HR.Department do
  @moduledoc "A team in the organization, with an optional head and parent department."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.Department.Attributes,
      Zippiker.HR.Department.Relationships,
      Zippiker.HR.Department.Aggregates,
      Zippiker.HR.Department.Actions,
      Zippiker.HR.Department.Policies
    ]

  postgres do
    table "departments"
    repo Zippiker.Repo

    references do
      reference :parent, on_delete: :nilify
      reference :head, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
  end
end
