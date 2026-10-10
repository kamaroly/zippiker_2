defmodule Zippiker.Accounts.Membership.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      public? true
      default :member
      constraints one_of: [:owner, :admin, :member]
    end

    timestamps()
  end
end
