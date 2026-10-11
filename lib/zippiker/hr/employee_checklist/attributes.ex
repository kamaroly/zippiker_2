defmodule Zippiker.HR.EmployeeChecklist.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:onboarding, :offboarding]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :in_progress
      constraints one_of: [:in_progress, :completed, :cancelled]
    end

    attribute :base_date, :date do
      description "Start date (onboarding) or leaving date (offboarding); due dates count from it."
      allow_nil? false
      public? true
      default &Date.utc_today/0
    end

    attribute :completed_at, :utc_datetime_usec, public?: true
    timestamps()
  end
end
