defmodule Zippiker.Parties.Party.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:person, :organization]
    end

    attribute :name, :string do
      description "Display name. Derived from first and last name for people."
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :first_name, :string, public?: true, constraints: [max_length: 100]
    attribute :last_name, :string, public?: true, constraints: [max_length: 100]
    attribute :job_title, :string, public?: true, constraints: [max_length: 120]
    attribute :email, :ci_string, public?: true
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :website, :string, public?: true, constraints: [max_length: 255]
    attribute :industry, :string, public?: true, constraints: [max_length: 120]
    attribute :tax_id, :string, public?: true, constraints: [max_length: 60]
    attribute :description, :string, public?: true, constraints: [max_length: 5_000]

    attribute :roles, {:array, :atom} do
      public? true
      allow_nil? false
      default []
      constraints items: [one_of: [:lead, :customer, :supplier, :partner, :employee]]
    end

    attribute :tags, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    timestamps()
  end
end
