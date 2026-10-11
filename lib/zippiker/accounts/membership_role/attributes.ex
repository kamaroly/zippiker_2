defmodule Zippiker.Accounts.MembershipRole.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end
end
