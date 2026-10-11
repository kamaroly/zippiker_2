defmodule Zippiker.Compliance.Shareholder do
  @moduledoc """
  A member of the company (register of members): a person or company with
  their identity and address. Their holdings come from share movements.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.Shareholder.Attributes,
      Zippiker.Compliance.Shareholder.Relationships,
      Zippiker.Compliance.Shareholder.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "shareholders"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
