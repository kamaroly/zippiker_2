defmodule Zippiker.HR.LeavePolicy do
  @moduledoc """
  A set of leave entitlements: which leave types apply and how many days per
  year each, with optional carry-over of unused days. Employees follow the
  policy assigned to them, or the default one. Without any policy, each
  leave type's own default allowance applies.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeavePolicy.Attributes,
      Zippiker.HR.LeavePolicy.Relationships,
      Zippiker.HR.LeavePolicy.Aggregates,
      Zippiker.HR.LeavePolicy.Actions,
      Zippiker.HR.LeavePolicy.Policies
    ]

  postgres do
    table "leave_policies"
    repo Zippiker.Repo
    identity_wheres_to_sql one_default: "\"default?\" = true"

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
    identity :one_default, [:default?], where: expr(default? == true)
  end
end
