defmodule Zippiker.HR.ChecklistTemplateTask do
  @moduledoc "A task of a checklist template."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.ChecklistTemplateTask.Attributes,
      Zippiker.HR.ChecklistTemplateTask.Relationships,
      Zippiker.HR.ChecklistTemplateTask.Actions,
      Zippiker.HR.LeaveType.Policies
    ]

  postgres do
    table "checklist_template_tasks"
    repo Zippiker.Repo

    references do
      reference :template, on_delete: :delete
      reference :user, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
