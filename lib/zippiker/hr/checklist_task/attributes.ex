defmodule Zippiker.HR.ChecklistTask.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :description, :string, public?: true, constraints: [max_length: 1_000]

    attribute :assignee_role, :atom do
      allow_nil? false
      public? true
      default :hr
      constraints one_of: [:hr, :manager, :employee, :user]
    end

    attribute :due_on, :date, public?: true
    attribute :requires_attachment?, :boolean, allow_nil?: false, public?: true, default: false

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :open
      constraints one_of: [:open, :done]
    end

    attribute :done_at, :utc_datetime_usec, public?: true
    attribute :note, :string, public?: true, constraints: [max_length: 1_000]
    timestamps()
  end
end
