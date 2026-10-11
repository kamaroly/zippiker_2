defmodule Zippiker.Sales.Invoice.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
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
    belongs_to :sales_order, Zippiker.Sales.SalesOrder, public?: true

    belongs_to :owner, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :lines, Zippiker.Sales.InvoiceLine do
      public? true
      sort position: :asc
    end

    has_many :payments, Zippiker.Sales.Payment do
      public? true
      sort paid_on: :desc
    end
  end
end
