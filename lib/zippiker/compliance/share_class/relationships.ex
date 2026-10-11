defmodule Zippiker.Compliance.ShareClass.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :profile, Zippiker.Compliance.CompanyProfile, allow_nil?: false, public?: true
  end
end
