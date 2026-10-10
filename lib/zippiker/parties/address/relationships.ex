defmodule Zippiker.Parties.Address.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
    end

    belongs_to :party, Zippiker.Parties.Party do
      allow_nil? false
      public? true
    end
  end
end
