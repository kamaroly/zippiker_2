defmodule Zippiker.Parties.Party.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
    end

    belongs_to :owner, Zippiker.Accounts.User do
      description "The team member responsible for this relationship."
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :employer, Zippiker.Parties.Party do
      description "For people: the organization they work for."
      public? true
    end

    has_many :employees, Zippiker.Parties.Party do
      destination_attribute :employer_id
      public? true
    end

    has_many :addresses, Zippiker.Parties.Address do
      public? true
    end
  end
end
