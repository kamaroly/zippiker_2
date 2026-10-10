defmodule Zippiker.HR.Employee.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :employee_number, :string, public?: true
    attribute :job_title, :string, public?: true, constraints: [max_length: 120]

    attribute :employment_type, :atom do
      allow_nil? false
      public? true
      default :full_time
      constraints one_of: [:full_time, :part_time, :contractor, :intern]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :active
      constraints one_of: [:active, :terminated]
    end

    attribute :hire_date, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :termination_date, :date, public?: true
    attribute :termination_reason, :string, public?: true, constraints: [max_length: 500]

    # Sensitive: see the field policies.
    attribute :salary, :decimal, public?: true, constraints: [min: 0]

    attribute :pay_frequency, :atom do
      allow_nil? false
      public? true
      default :monthly
      constraints one_of: [:monthly, :biweekly, :weekly, :hourly, :yearly]
    end

    attribute :date_of_birth, :date, public?: true
    attribute :national_id, :string, public?: true, constraints: [max_length: 60]
    attribute :emergency_contact_name, :string, public?: true, constraints: [max_length: 120]
    attribute :emergency_contact_phone, :string, public?: true, constraints: [max_length: 40]
    attribute :notes, :string, public?: true, constraints: [max_length: 5_000]

    timestamps()
  end
end
