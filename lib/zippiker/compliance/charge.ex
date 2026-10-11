defmodule Zippiker.Compliance.Charge do
  @moduledoc """
  Register of charges: security given over the company's assets (mortgages,
  debentures…), to whom, for how much, and when satisfied. A new charge
  adds its registration to the filing calendar.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.Charge.Attributes,
      Zippiker.Compliance.Charge.Relationships,
      Zippiker.Compliance.Charge.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "company_charges"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
