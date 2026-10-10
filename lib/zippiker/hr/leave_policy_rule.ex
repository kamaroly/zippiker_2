defmodule Zippiker.HR.LeavePolicyRule do
  @moduledoc "One entitlement in a leave policy: a leave type, days per year, carry-over."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeavePolicyRule.Attributes,
      Zippiker.HR.LeavePolicyRule.Relationships,
      Zippiker.HR.LeavePolicyRule.Actions,
      Zippiker.HR.LeavePolicy.Policies
    ]

  postgres do
    table "leave_policy_rules"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :leave_policy, on_delete: :delete
      reference :leave_type, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_type, [:leave_policy_id, :leave_type_id]
  end
end
