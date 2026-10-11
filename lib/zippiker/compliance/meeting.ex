defmodule Zippiker.Compliance.Meeting do
  @moduledoc """
  A board meeting, general meeting (AGM/EGM) or written resolution: notice,
  agenda, attendees and minutes, with its resolutions.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.Meeting.Attributes,
      Zippiker.Compliance.Meeting.Relationships,
      Zippiker.Compliance.Meeting.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "company_meetings"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
