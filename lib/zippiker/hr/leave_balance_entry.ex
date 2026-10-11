defmodule Zippiker.HR.LeaveBalanceEntry do
  @moduledoc """
  A change to an employee's leave balance outside requests: days accrued
  (by the daily accrual job, one entry per period), admin adjustments
  (+/-), and approved claims. Balances are these entries plus the fixed
  yearly allowance, minus pending and approved leave (`Zippiker.HR.Entitlement`).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeaveBalanceEntry.Attributes,
      Zippiker.HR.LeaveBalanceEntry.Relationships,
      Zippiker.HR.LeaveBalanceEntry.Actions,
      Zippiker.HR.LeaveBalanceEntry.Policies
    ]

  postgres do
    table "leave_balance_entries"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :employee, on_delete: :delete
      reference :leave_type, on_delete: :delete
      reference :leave_policy, on_delete: :nilify
      reference :claim, on_delete: :nilify
      reference :created_by, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :employee_id, :leave_type_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :one_accrual_per_period, [:employee_id, :leave_policy_id, :period]
  end
end
