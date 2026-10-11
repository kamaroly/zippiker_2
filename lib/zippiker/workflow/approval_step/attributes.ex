defmodule Zippiker.Workflow.ApprovalStep.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 1
    attribute :label, :string, public?: true, constraints: [max_length: 80]

    attribute :approver_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:manager, :manager_or_admins, :user, :group, :admins]
    end
  end
end
