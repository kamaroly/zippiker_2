defmodule Zippiker.Purchasing.PurchaseOrder.Relationships do
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

    belongs_to :warehouse, Zippiker.Inventory.Warehouse do
      public? true
      domain Zippiker.Inventory
    end

    belongs_to :rfq, Zippiker.Purchasing.Rfq, public?: true

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :lines, Zippiker.Purchasing.PurchaseOrderLine do
      public? true
      sort position: :asc
    end

    has_one :bill, Zippiker.Purchasing.Bill do
      public? true
      filter expr(status != :void)
    end
  end
end
