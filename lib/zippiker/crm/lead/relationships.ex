defmodule Zippiker.Crm.Lead.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :party, Zippiker.Parties.Party do
      description "The contact created on conversion."
      public? true
      domain Zippiker.Parties
    end

    belongs_to :company, Zippiker.Parties.Party do
      description "The company created or matched on conversion."
      public? true
      domain Zippiker.Parties
    end

    has_one :deal, Zippiker.Crm.Deal do
      public? true
    end
  end
end
