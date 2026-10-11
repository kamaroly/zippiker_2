defmodule Zippiker.Accounts.MembershipRole.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :membership, Zippiker.Accounts.Membership, allow_nil?: false, public?: true
    belongs_to :role, Zippiker.Accounts.Role, allow_nil?: false, public?: true
  end
end
