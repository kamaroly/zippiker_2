defmodule Zippiker.Accounts.Branch.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :manager, Zippiker.Accounts.User do
      description "Who runs the branch."
      public? true
    end
  end
end
