defmodule Zippiker.Crm.Lead.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      description "Full name, derived from first and last name."
      allow_nil? false
      public? true
    end

    attribute :first_name, :string, public?: true, constraints: [max_length: 100]
    attribute :last_name, :string, public?: true, constraints: [max_length: 100]
    attribute :company_name, :string, public?: true, constraints: [max_length: 200]
    attribute :job_title, :string, public?: true, constraints: [max_length: 120]
    attribute :email, :ci_string, public?: true
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :notes, :string, public?: true, constraints: [max_length: 5_000]

    attribute :source, :atom do
      public? true
      allow_nil? false
      default :other

      constraints one_of: [
                    :website,
                    :referral,
                    :event,
                    :cold_outreach,
                    :social,
                    :advertising,
                    :other
                  ]
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      default :new
      constraints one_of: [:new, :contacted, :qualified, :disqualified, :converted]
    end

    attribute :converted_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
