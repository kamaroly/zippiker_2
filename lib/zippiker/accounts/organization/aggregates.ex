defmodule Zippiker.Accounts.Organization.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :members_count, :memberships, public?: true
  end
end
