defmodule Zippiker.Workflow.ApprovalStep.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:position, :label, :approver_type, :user_id, :group_id]
      validate Zippiker.Workflow.ApprovalStep.Validations.ApproverChosen
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:position, :label, :approver_type, :user_id, :group_id]
      validate Zippiker.Workflow.ApprovalStep.Validations.ApproverChosen
    end
  end
end
