defmodule Zippiker.HR.ChecklistTemplate.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :tasks, Zippiker.HR.ChecklistTemplateTask do
      public? true
      destination_attribute :template_id
      sort position: :asc
    end
  end
end
