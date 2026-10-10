defmodule Zippiker.Purchasing.Bill.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
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

    belongs_to :purchase_order, Zippiker.Purchasing.PurchaseOrder, public?: true

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :lines, Zippiker.Purchasing.BillLine do
      public? true
      sort position: :asc
    end

    has_many :payments, Zippiker.Purchasing.BillPayment do
      public? true
      sort paid_on: :desc
    end
  end
end
