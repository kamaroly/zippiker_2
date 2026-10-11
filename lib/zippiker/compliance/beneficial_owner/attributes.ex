defmodule Zippiker.Compliance.BeneficialOwner.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :nationality, :string, public?: true, constraints: [max_length: 60]
    attribute :id_number, :string, public?: true, constraints: [max_length: 40]
    attribute :kra_pin, :string, public?: true, constraints: [max_length: 20]
    attribute :date_of_birth, :date, public?: true
    attribute :address, :string, public?: true, constraints: [max_length: 300]
    attribute :email, :string, public?: true, constraints: [max_length: 160]
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :shares_percent, :decimal, public?: true, constraints: [min: 0, max: 100]
    attribute :voting_percent, :decimal, public?: true, constraints: [min: 0, max: 100]
    attribute :appoints_directors?, :boolean, allow_nil?: false, public?: true, default: false
    attribute :significant_influence?, :boolean, allow_nil?: false, public?: true, default: false

    attribute :became_owner_on, :date,
      allow_nil?: false,
      public?: true,
      default: &Date.utc_today/0

    attribute :ceased_on, :date, public?: true
    timestamps()
  end
end
