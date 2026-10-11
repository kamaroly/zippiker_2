defmodule Zippiker.HR.ChecklistTask do
  @moduledoc """
  One task of an employee's checklist. Its assignee (or any admin) marks it
  done, with a note and attachments; tasks that need proof can't be done
  without an attachment.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.ChecklistTask.Attributes,
      Zippiker.HR.ChecklistTask.Relationships,
      Zippiker.HR.ChecklistTask.Actions,
      Zippiker.HR.ChecklistTask.Policies
    ]

  postgres do
    table "checklist_tasks"
    repo Zippiker.Repo

    references do
      reference :checklist, on_delete: :delete
      reference :assignee, on_delete: :nilify
      reference :done_by, on_delete: :nilify
    end

    custom_indexes do
      index [:assignee_id, :status]
    end
  end

  multitenancy do
    strategy :context
  end

  aggregates do
    count :attachments_count, :attachments, public?: true
  end
end
