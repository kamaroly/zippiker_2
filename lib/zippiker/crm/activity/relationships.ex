defmodule Zippiker.Crm.Activity.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :author, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :party, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end

    belongs_to :deal, Zippiker.Crm.Deal, public?: true
    belongs_to :lead, Zippiker.Crm.Lead, public?: true
  end
end
