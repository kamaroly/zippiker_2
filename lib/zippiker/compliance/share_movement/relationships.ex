defmodule Zippiker.Compliance.ShareMovement.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :profile, Zippiker.Compliance.CompanyProfile, allow_nil?: false, public?: true

    belongs_to :shareholder, Zippiker.Compliance.Shareholder, allow_nil?: false, public?: true
    belongs_to :share_class, Zippiker.Compliance.ShareClass, allow_nil?: false, public?: true
  end
end
