defmodule Zippiker.Compliance.Resolution do
  @moduledoc """
  A resolution of a meeting (or a written resolution): its text, whether
  ordinary, special or a board resolution, and whether it passed. Passed
  special resolutions are filed with the Registrar.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.Resolution.Attributes,
      Zippiker.Compliance.Resolution.Relationships,
      Zippiker.Compliance.Resolution.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "company_resolutions"
    repo Zippiker.Repo

    references do
      reference :meeting, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
