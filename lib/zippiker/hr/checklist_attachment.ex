defmodule Zippiker.HR.ChecklistAttachment do
  @moduledoc "A file attached to a checklist task (signed contract, ID copy, clearance form…)."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.ChecklistAttachment.Attributes,
      Zippiker.HR.ChecklistAttachment.Relationships,
      Zippiker.HR.ChecklistAttachment.Actions,
      Zippiker.HR.ChecklistAttachment.Policies
    ]

  postgres do
    table "checklist_attachments"
    repo Zippiker.Repo

    references do
      reference :task, on_delete: :delete
      reference :uploaded_by, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
