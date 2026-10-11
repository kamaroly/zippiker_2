defmodule Zippiker.Parties.Address do
  @moduledoc "A postal address of a party."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Parties,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Parties.Address.Attributes,
      Zippiker.Parties.Address.Relationships,
      Zippiker.Parties.Address.Actions,
      Zippiker.Parties.Address.Policies
    ]

  postgres do
    table "addresses"
    repo Zippiker.Repo

    references do
      reference :party, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
