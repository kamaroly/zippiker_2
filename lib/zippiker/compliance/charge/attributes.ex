defmodule Zippiker.Compliance.Charge.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :chargee, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]

    attribute :description, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 1_000]

    attribute :amount_secured, :decimal, public?: true, constraints: [min: 0]
    attribute :currency, :string, allow_nil?: false, public?: true, default: "KES"
    attribute :created_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :registered_on, :date, public?: true
    attribute :registration_number, :string, public?: true, constraints: [max_length: 60]
    attribute :satisfied_on, :date, public?: true
    timestamps()
  end

  calculations do
    calculate :outstanding?, :boolean, expr(is_nil(satisfied_on)), public?: true
  end
end
