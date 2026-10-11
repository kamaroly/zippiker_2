defmodule Zippiker.Compliance.CompanyProfile do
  @moduledoc """
  The statutory details of a company (one per legal entity): registration
  number, type, incorporation date, KRA PIN, registered office, financial
  year end and share capital. Its registers and filing calendar hang off it.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.CompanyProfile.Attributes,
      Zippiker.Compliance.CompanyProfile.Relationships,
      Zippiker.Compliance.CompanyProfile.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "company_profiles"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :one_per_legal_entity, [:legal_entity_id]
  end
end
