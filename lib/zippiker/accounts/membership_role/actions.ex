defmodule Zippiker.Accounts.MembershipRole.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy, create: [:membership_id, :role_id]]
  end
end
