defmodule Zippiker.HR.LeaveClaim do
  @moduledoc """
  An employee asks for days to be added to their balance (e.g. time off in
  lieu after working a weekend). Only leave types whose policy is
  `claimable?`. Their manager or an admin approves (never themselves); an
  approved claim becomes a balance entry.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeaveClaim.Attributes,
      Zippiker.HR.LeaveClaim.Relationships,
      Zippiker.HR.LeaveClaim.Actions,
      Zippiker.HR.LeaveClaim.Policies
    ]

  postgres do
    table "leave_claims"
    repo Zippiker.Repo

    references do
      reference :employee, on_delete: :delete
      reference :leave_type, on_delete: :restrict
      reference :leave_policy, on_delete: :nilify
      reference :decided_by, on_delete: :nilify
    end

    custom_indexes do
      index [:status]
    end
  end

  multitenancy do
    strategy :context
  end
end
