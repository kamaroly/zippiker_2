defmodule Zippiker.HR.TimeActivity.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :employee, Zippiker.HR.Employee, allow_nil?: false, public?: true

    belongs_to :customer, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end

    belongs_to :deal, Zippiker.Crm.Deal do
      description "The project the time was spent on."
      public? true
      domain Zippiker.Crm
    end

    belongs_to :product, Zippiker.Catalog.Product do
      description "The service the time is billed as."
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :invoice, Zippiker.Sales.Invoice do
      description "The invoice the time was billed on; empty while unbilled."
      public? true
      domain Zippiker.Sales
    end
  end
end
