defmodule Zippiker.Compliance.CompanyProfile.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    has_many :officers, Zippiker.Compliance.Officer,
      destination_attribute: :profile_id,
      public?: true

    has_many :shareholders, Zippiker.Compliance.Shareholder,
      destination_attribute: :profile_id,
      public?: true

    has_many :share_classes, Zippiker.Compliance.ShareClass,
      destination_attribute: :profile_id,
      public?: true

    has_many :tasks, Zippiker.Compliance.ComplianceTask,
      destination_attribute: :profile_id,
      public?: true
  end
end
