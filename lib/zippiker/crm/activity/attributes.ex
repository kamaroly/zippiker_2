defmodule Zippiker.Crm.Activity.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :note
      constraints one_of: [:note, :call, :email, :meeting]
    end

    attribute :subject, :string, public?: true, constraints: [max_length: 200]
    attribute :body, :string, allow_nil?: false, public?: true, constraints: [max_length: 10_000]

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    timestamps()
  end
end
