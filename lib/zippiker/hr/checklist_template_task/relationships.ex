defmodule Zippiker.HR.ChecklistTemplateTask.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :template, Zippiker.HR.ChecklistTemplate, allow_nil?: false, public?: true

    belongs_to :user, Zippiker.Accounts.User do
      description "The assignee when `assignee_role` is :user."
      public? true
      domain Zippiker.Accounts
    end
  end
end
