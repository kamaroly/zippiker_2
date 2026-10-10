defmodule Zippiker.Accounts.User.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :memberships, Zippiker.Accounts.Membership
  end
end
