defmodule Zippiker.HR.ChecklistTemplateTask.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :description, :string, public?: true, constraints: [max_length: 1_000]

    attribute :assignee_role, :atom do
      description "hr: any workspace admin; manager: the employee's manager; employee: the person; user: `user_id`."
      allow_nil? false
      public? true
      default :hr
      constraints one_of: [:hr, :manager, :employee, :user]
    end

    attribute :due_in_days, :integer do
      description "Days after the start (or leaving) date it's due; negative = before."
      allow_nil? false
      public? true
      default 0
    end

    attribute :requires_attachment?, :boolean, allow_nil?: false, public?: true, default: false
  end
end
