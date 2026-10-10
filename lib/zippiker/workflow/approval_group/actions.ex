defmodule Zippiker.Workflow.ApprovalGroup.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [name: :asc], load: [:members])
    end

    create :create do
      primary? true
      accept [:name, :description]
      argument :member_ids, {:array, :uuid}, default: []
      change manage_relationship(:member_ids, :members, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :description]
      argument :member_ids, {:array, :uuid}
      change manage_relationship(:member_ids, :members, type: :append_and_remove)
    end
  end
end
