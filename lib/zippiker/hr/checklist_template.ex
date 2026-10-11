defmodule Zippiker.HR.ChecklistTemplate do
  @moduledoc """
  A reusable onboarding or offboarding checklist: the tasks to do, who
  does each (HR, the manager, the employee or a named person), when (days
  from the start/leaving date) and whether proof must be attached. The
  default template of each kind starts automatically when someone is hired
  or marked as leaving.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.ChecklistTemplate.Attributes,
      Zippiker.HR.ChecklistTemplate.Relationships,
      Zippiker.HR.ChecklistTemplate.Actions,
      Zippiker.HR.LeaveType.Policies
    ]

  postgres do
    table "checklist_templates"
    repo Zippiker.Repo
    identity_wheres_to_sql one_default_per_kind: "\"default?\" = true"
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
    identity :one_default_per_kind, [:kind], where: expr(default? == true)
  end
end
