defmodule Zippiker.HR.LeavePolicy do
  @moduledoc """
  How one leave type works for the people on the policy: how days are
  granted (`category`: a fixed yearly allowance, accrued over time by the
  daily Oban job, manual adjustments only, or unlimited), from when
  (`effective_date`), and the request rules — attachment required, counting
  weekends and holidays, backdating, claiming (e.g. overtime), and what
  happens when nobody reviews a request within `review_threshold_days`.

  Employees get one policy per leave type (`LeavePolicyAssignment`); the
  type's default policy covers everyone else. Without any policy, the leave
  type's own allowance applies.
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
    identity_wheres_to_sql one_default_per_type: "\"default?\" = true"

    references do
      reference :leave_type, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
    identity :one_default_per_type, [:leave_type_id], where: expr(default? == true)
  end
end
