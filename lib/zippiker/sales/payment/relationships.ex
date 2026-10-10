defmodule Zippiker.Sales.Payment.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :invoice, Zippiker.Sales.Invoice, allow_nil?: false, public?: true

    belongs_to :recorded_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
