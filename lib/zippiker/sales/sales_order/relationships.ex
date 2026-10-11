defmodule Zippiker.Sales.SalesOrder.Relationships do
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

    belongs_to :customer, Zippiker.Parties.Party do
      allow_nil? false
      public? true
      domain Zippiker.Parties
    end

    belongs_to :contact, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end

    belongs_to :deal, Zippiker.Crm.Deal do
      public? true
      domain Zippiker.Crm
    end

    belongs_to :quote, Zippiker.Sales.Quote, public?: true

    belongs_to :warehouse, Zippiker.Inventory.Warehouse do
      public? true
      domain Zippiker.Inventory
    end

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :lines, Zippiker.Sales.SalesOrderLine do
      public? true
      sort position: :asc
    end

    has_one :invoice, Zippiker.Sales.Invoice do
      public? true
      filter expr(status != :void)
    end
  end
end
