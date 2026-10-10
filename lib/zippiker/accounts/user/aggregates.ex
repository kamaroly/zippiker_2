defmodule Zippiker.Accounts.User.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    count :memberships_count, :memberships, public?: true
  end
end
