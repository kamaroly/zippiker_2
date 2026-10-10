defmodule Zippiker.HR.Department.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :list do
      prepare build(sort: [name: :asc], load: [:headcount, :parent, head: [:party]])
    end

    create :create do
      primary? true
      accept [:name, :description, :parent_id, :head_id]
    end

    update :update do
      primary? true
      accept [:name, :description, :parent_id, :head_id]
      require_atomic? false
      validate {Zippiker.HR.Department.Validations.NotOwnParent, []}
    end

    destroy :destroy do
      primary? true
    end
  end
end
