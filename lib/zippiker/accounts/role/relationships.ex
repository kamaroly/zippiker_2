defmodule Zippiker.Accounts.Role.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      public? true
    end

    many_to_many :memberships, Zippiker.Accounts.Membership do
      through Zippiker.Accounts.MembershipRole
      source_attribute_on_join_resource :role_id
      destination_attribute_on_join_resource :membership_id
      public? true
    end
  end

  aggregates do
    count :members_count, :memberships, public?: true
  end
end
