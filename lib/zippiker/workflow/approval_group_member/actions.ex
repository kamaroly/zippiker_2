defmodule Zippiker.Workflow.ApprovalGroupMember.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy, create: [:group_id, :user_id]]
  end
end
