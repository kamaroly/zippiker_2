defmodule Zippiker.Compliance.Shareholder.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :person
      constraints one_of: [:person, :company]
    end

    attribute :id_number, :string do
      description "ID / passport number, or registration number for a company."
      public? true
      constraints max_length: 40
    end

    attribute :nationality, :string, public?: true, constraints: [max_length: 60]
    attribute :address, :string, public?: true, constraints: [max_length: 300]
    attribute :email, :string, public?: true, constraints: [max_length: 160]
    attribute :entered_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :ceased_on, :date, public?: true
    timestamps()
  end

  aggregates do
    sum :shares_held, :movements, :quantity do
      public? true
      default 0
    end
  end
end
