defmodule Zippiker.Parties.Address.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :main
      constraints one_of: [:main, :billing, :shipping, :other]
    end

    attribute :line1, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :line2, :string, public?: true, constraints: [max_length: 200]
    attribute :city, :string, public?: true, constraints: [max_length: 120]
    attribute :region, :string, public?: true, constraints: [max_length: 120]
    attribute :postal_code, :string, public?: true, constraints: [max_length: 20]

    attribute :country, :string,
      public?: true,
      constraints: [max_length: 2, match: ~r/^[A-Z]{2}$/]

    timestamps()
  end
end
