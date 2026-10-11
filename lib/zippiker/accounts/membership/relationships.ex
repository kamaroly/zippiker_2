defmodule Zippiker.Accounts.Membership.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :user, Zippiker.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      public? true
    end

    many_to_many :roles, Zippiker.Accounts.Role do
      through Zippiker.Accounts.MembershipRole
      source_attribute_on_join_resource :membership_id
      destination_attribute_on_join_resource :role_id
      public? true
    end
  end
end
