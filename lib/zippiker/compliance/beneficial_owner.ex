defmodule Zippiker.Compliance.BeneficialOwner do
  @moduledoc """
  Register of beneficial owners: natural persons who ultimately own or
  control the company (10% or more of shares or votes, the right to appoint
  or remove a director, or significant influence). Changes add a filing to
  the calendar.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.BeneficialOwner.Attributes,
      Zippiker.Compliance.BeneficialOwner.Relationships,
      Zippiker.Compliance.BeneficialOwner.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "beneficial_owners"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
