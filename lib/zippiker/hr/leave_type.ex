defmodule Zippiker.HR.LeaveType do
  @moduledoc "A kind of time off (annual, sick, unpaid…) with its yearly allowance."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeaveType.Attributes,
      Zippiker.HR.LeaveType.Relationships,
      Zippiker.HR.LeaveType.Actions,
      Zippiker.HR.LeaveType.Policies
    ]

  postgres do
    table "leave_types"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_name, [:name]
  end
end
