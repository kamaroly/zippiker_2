defmodule Zippiker.Compliance.CompanyProfile.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :registration_number, :string, public?: true, constraints: [max_length: 40]

    attribute :company_type, :atom do
      allow_nil? false
      public? true
      default :private_limited
      constraints one_of: [:private_limited, :public_limited, :guarantee, :unlimited, :foreign]
    end

    attribute :incorporation_date, :date, public?: true
    attribute :kra_pin, :string, public?: true, constraints: [max_length: 20]
    attribute :registered_office, :string, public?: true, constraints: [max_length: 500]
    attribute :postal_address, :string, public?: true, constraints: [max_length: 200]
    attribute :email, :string, public?: true, constraints: [max_length: 160]

    attribute :year_end_month, :integer do
      description "Financial year end (month)."
      allow_nil? false
      public? true
      default 12
      constraints min: 1, max: 12
    end

    attribute :year_end_day, :integer,
      allow_nil?: false,
      public?: true,
      default: 31,
      constraints: [min: 1, max: 31]

    attribute :authorised_capital, :decimal, public?: true, constraints: [min: 0]
    attribute :auditor, :string, public?: true, constraints: [max_length: 200]

    attribute :secretary_required?, :boolean do
      description "Public companies, and private ones with paid-up capital of KES 5 million or more, must have a secretary."
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end
end
