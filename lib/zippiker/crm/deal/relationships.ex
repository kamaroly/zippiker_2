defmodule Zippiker.Crm.Deal.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :pipeline, Zippiker.Crm.Pipeline, allow_nil?: false, public?: true
    belongs_to :stage, Zippiker.Crm.Stage, allow_nil?: false, public?: true

    belongs_to :party, Zippiker.Parties.Party do
      description "The main contact person."
      public? true
      domain Zippiker.Parties
    end

    belongs_to :company, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :lead, Zippiker.Crm.Lead do
      description "The lead this deal was converted from."
      public? true
      attribute_writable? true
    end
  end
end
