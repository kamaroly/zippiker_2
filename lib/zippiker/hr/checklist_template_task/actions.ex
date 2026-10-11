defmodule Zippiker.HR.ChecklistTemplateTask.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :position,
    :title,
    :description,
    :assignee_role,
    :user_id,
    :due_in_days,
    :requires_attachment?
  ]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:template_id | @fields]
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
