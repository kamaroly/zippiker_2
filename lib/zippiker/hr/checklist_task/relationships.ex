defmodule Zippiker.HR.ChecklistTask.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :checklist, Zippiker.HR.EmployeeChecklist, allow_nil?: false, public?: true

    belongs_to :assignee, Zippiker.Accounts.User do
      description "Who does it; empty for HR tasks (any admin)."
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :done_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :attachments, Zippiker.HR.ChecklistAttachment do
      public? true
      destination_attribute :task_id
    end
  end
end
