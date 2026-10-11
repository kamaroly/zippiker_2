defmodule Zippiker.Purchasing.Rfq.Relationships do
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

    belongs_to :supplier, Zippiker.Parties.Party do
      allow_nil? false
      public? true
      domain Zippiker.Parties
    end

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :lines, Zippiker.Purchasing.RfqLine do
      public? true
      sort position: :asc
    end

    has_one :purchase_order, Zippiker.Purchasing.PurchaseOrder do
      public? true
      filter expr(status != :cancelled)
    end
  end
end
