defmodule Zippiker.Compliance.Meeting.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :board
      constraints one_of: [:board, :agm, :egm, :written_resolution]
    end

    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :held_on, :date, allow_nil?: false, public?: true
    attribute :location, :string, public?: true, constraints: [max_length: 200]
    attribute :notice_sent_on, :date, public?: true
    attribute :agenda, :string, public?: true, constraints: [max_length: 5_000]
    attribute :attendees, :string, public?: true, constraints: [max_length: 2_000]
    attribute :minutes, :string, public?: true, constraints: [max_length: 50_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :planned
      constraints one_of: [:planned, :held, :cancelled]
    end

    timestamps()
  end
end
