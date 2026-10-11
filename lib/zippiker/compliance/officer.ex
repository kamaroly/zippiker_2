defmodule Zippiker.Compliance.Officer do
  @moduledoc """
  Register of directors and secretaries: who, their role, identity and
  addresses, appointed and ceased dates. Appointments and cessations add a
  notice to file with the Registrar to the filing calendar.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.Officer.Attributes,
      Zippiker.Compliance.Officer.Relationships,
      Zippiker.Compliance.Officer.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "company_officers"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
