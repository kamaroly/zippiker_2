defmodule Zippiker.Accounting.JournalEntry.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :branch, Zippiker.Accounts.Branch do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :posted_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :reversal_of, Zippiker.Accounting.JournalEntry, public?: true

    has_one :reversal, Zippiker.Accounting.JournalEntry do
      public? true
      destination_attribute :reversal_of_id
    end

    has_many :lines, Zippiker.Accounting.JournalLine do
      public? true
      sort position: :asc
    end
  end
end
