defmodule Zippiker.HR.Employee do
  @moduledoc """
  Someone who works for the organization. Name, email and phone live on the
  linked `Zippiker.Parties` person (shared with every module); the employee
  adds the job: number (`EMP-0001`), title, department, manager, contract and
  pay. Linking a workspace user lets them request leave and approve their
  reports' requests. Pay and personal details are visible only to admins and
  the employee themselves.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource, Zippiker.Extensibility.CustomFields],
    fragments: [
      Zippiker.HR.Employee.Attributes,
      Zippiker.HR.Employee.Relationships,
      Zippiker.HR.Employee.Aggregates,
      Zippiker.HR.Employee.Calculations,
      Zippiker.HR.Employee.Actions,
      Zippiker.HR.Employee.Policies
    ]

  postgres do
    table "employees"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_user: "user_id IS NOT NULL",
                           unique_number: "employee_number IS NOT NULL"

    references do
      reference :branch, on_delete: :restrict
      reference :legal_entity, on_delete: :restrict
      reference :party, on_delete: :restrict
      reference :user, on_delete: :nilify
      reference :department, on_delete: :nilify
      reference :manager, on_delete: :nilify
    end

    custom_indexes do
      index [:status]
      index [:manager_id]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    reference_source? false
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:employee)
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_number, [:employee_number], where: expr(not is_nil(employee_number))
    identity :unique_user, [:user_id], where: expr(not is_nil(user_id))
  end
end
