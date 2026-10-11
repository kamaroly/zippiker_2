defmodule Zippiker.HR.LeaveRequest.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :start_date, :date, allow_nil?: false, public?: true
    attribute :end_date, :date, allow_nil?: false, public?: true

    attribute :days, :decimal do
      description "Working days (Mon–Fri) between the dates, inclusive."
      allow_nil? false
      public? true
      default 0
    end

    attribute :reason, :string, public?: true, constraints: [max_length: 1_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :approved, :rejected, :cancelled]
    end

    attribute :decided_at, :utc_datetime_usec, public?: true
    attribute :decision_note, :string, public?: true, constraints: [max_length: 500]

    attribute :auto_decided?, :boolean do
      description "Approved or rejected automatically after the policy's review threshold."
      allow_nil? false
      public? true
      default false
    end

    attribute :attachment_name, :string, public?: true, constraints: [max_length: 255]

    attribute :attachment_path, :string do
      description "Where the uploaded file is stored, relative to the uploads directory."
      public? true
      constraints max_length: 500
    end

    timestamps()
  end
end
