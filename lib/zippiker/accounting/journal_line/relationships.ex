defmodule Zippiker.Accounting.JournalLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :journal_entry, Zippiker.Accounting.JournalEntry do
      allow_nil? false
      public? true
    end

    belongs_to :account, Zippiker.Accounting.Account do
      allow_nil? false
      public? true
    end

    belongs_to :party, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end
  end
end
