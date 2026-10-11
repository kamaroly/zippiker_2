defmodule Zippiker.HR.Holiday do
  @moduledoc """
  A public holiday. Leave doesn't count it (or weekends) unless the leave
  policy says to count them. `recurring?` holidays fall on the same day
  every year (e.g. New Year's Day).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.Holiday.Attributes,
      Zippiker.HR.Holiday.Relationships,
      Zippiker.HR.Holiday.Actions,
      Zippiker.HR.LeaveType.Policies
    ]

  postgres do
    table "holidays"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
    end

    custom_indexes do
      index [:organization_id, :date]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
