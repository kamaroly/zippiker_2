defmodule Zippiker.Workflow.ApprovalGroup.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    has_many :memberships, Zippiker.Workflow.ApprovalGroupMember, destination_attribute: :group_id

    many_to_many :members, Zippiker.Accounts.User do
      public? true
      through Zippiker.Workflow.ApprovalGroupMember
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
      join_relationship :memberships
      domain Zippiker.Accounts
    end
  end
end
