defmodule Zippiker.Workflow.ApprovalRequestStep.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:position, :label, :approver_type, :user_id, :group_id]
    end

    update :set_status do
      accept [:status, :decided_at, :comment, :decided_by_id]
    end
  end
end
