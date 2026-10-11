defmodule Zippiker.HR.ChecklistAttachment.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:task_id, :name, :path]
      change relate_actor(:uploaded_by)
    end
  end
end
