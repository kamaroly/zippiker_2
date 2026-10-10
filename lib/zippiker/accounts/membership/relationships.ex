defmodule Zippiker.Accounts.Membership.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :user, Zippiker.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      public? true
    end
  end
end
