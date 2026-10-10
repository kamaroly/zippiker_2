defmodule Zippiker.Accounts.LegalEntity.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization, allow_nil?: false
  end
end
