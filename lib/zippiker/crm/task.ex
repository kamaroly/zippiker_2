defmodule Zippiker.Crm.Task do
  @moduledoc "A to-do with an optional due date, linked to any CRM record."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Crm.Task.Attributes,
      Zippiker.Crm.Task.Relationships,
      Zippiker.Crm.Task.Calculations,
      Zippiker.Crm.Task.Actions,
      Zippiker.Crm.Task.Policies
    ]

  postgres do
    table "tasks"
    repo Zippiker.Repo

    references do
      reference :party, on_delete: :delete
      reference :deal, on_delete: :delete
      reference :lead, on_delete: :delete
      reference :assignee, on_delete: :nilify
    end

    custom_indexes do
      index [:assignee_id, :completed_at, :due_on]
    end
  end

  multitenancy do
    strategy :context
  end
end
