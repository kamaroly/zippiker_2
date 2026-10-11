defmodule Zippiker.Compliance.StatutoryDocument.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :profile, Zippiker.Compliance.CompanyProfile, allow_nil?: false, public?: true

    belongs_to :uploaded_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
