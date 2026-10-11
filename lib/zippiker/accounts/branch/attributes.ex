defmodule Zippiker.Accounts.Branch.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]

    attribute :code, :string do
      description "Short code shown on documents and reports (e.g. HQ, NBO)."
      allow_nil? false
      public? true
      constraints max_length: 12, match: ~r/^[A-Za-z0-9\-]+$/
    end

    attribute :line1, :string, public?: true, constraints: [max_length: 200]
    attribute :city, :string, public?: true, constraints: [max_length: 100]
    attribute :country, :string, public?: true, constraints: [max_length: 2]
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :email, :string, public?: true, constraints: [max_length: 160]
    attribute :default?, :boolean, allow_nil?: false, public?: true, default: false
    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
