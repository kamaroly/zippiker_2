defmodule Zippiker.Platform.BillingInvoice.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end
  end
end
