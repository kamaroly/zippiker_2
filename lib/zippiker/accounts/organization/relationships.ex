defmodule Zippiker.Accounts.Organization.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :portal_accesses, Zippiker.Accounts.PortalAccess

    has_many :memberships, Zippiker.Accounts.Membership

    many_to_many :users, Zippiker.Accounts.User do
      through Zippiker.Accounts.Membership
      source_attribute_on_join_resource :organization_id
      destination_attribute_on_join_resource :user_id
    end
  end
end
