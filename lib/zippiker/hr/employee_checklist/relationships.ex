defmodule Zippiker.HR.EmployeeChecklist.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :employee, Zippiker.HR.Employee, allow_nil?: false, public?: true
    belongs_to :template, Zippiker.HR.ChecklistTemplate, public?: true

    belongs_to :started_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :tasks, Zippiker.HR.ChecklistTask do
      public? true
      destination_attribute :checklist_id
      sort position: :asc
    end
  end
end
