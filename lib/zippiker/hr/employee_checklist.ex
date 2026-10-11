defmodule Zippiker.HR.EmployeeChecklist do
  @moduledoc """
  An onboarding or offboarding checklist running for one employee, copied
  from a template: each task has its assignee and due date. It completes
  when every task is done.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.EmployeeChecklist.Attributes,
      Zippiker.HR.EmployeeChecklist.Relationships,
      Zippiker.HR.EmployeeChecklist.Actions,
      Zippiker.HR.EmployeeChecklist.Policies
    ]

  postgres do
    table "employee_checklists"
    repo Zippiker.Repo

    references do
      reference :employee, on_delete: :delete
      reference :template, on_delete: :nilify
      reference :started_by, on_delete: :nilify
    end

    custom_indexes do
      index [:status]
      index [:employee_id]
    end
  end

  multitenancy do
    strategy :context
  end

  aggregates do
    count :tasks_count, :tasks, public?: true

    count :done_count, :tasks do
      public? true
      filter expr(status == :done)
    end
  end
end
