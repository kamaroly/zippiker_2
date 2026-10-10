defmodule Zippiker.Crm.Task.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :notes, :string, public?: true, constraints: [max_length: 5_000]
    attribute :due_on, :date, public?: true

    attribute :priority, :atom do
      allow_nil? false
      public? true
      default :normal
      constraints one_of: [:low, :normal, :high]
    end

    attribute :completed_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
