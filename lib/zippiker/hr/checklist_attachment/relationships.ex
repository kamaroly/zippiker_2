defmodule Zippiker.HR.ChecklistAttachment.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :task, Zippiker.HR.ChecklistTask, allow_nil?: false, public?: true

    belongs_to :uploaded_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
