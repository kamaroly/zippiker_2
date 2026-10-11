defmodule Zippiker.Compliance.Shareholder.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :profile, Zippiker.Compliance.CompanyProfile, allow_nil?: false, public?: true

    has_many :movements, Zippiker.Compliance.ShareMovement do
      public? true
      destination_attribute :shareholder_id
    end
  end
end
