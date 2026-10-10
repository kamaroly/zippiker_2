defmodule Zippiker.Accounting.JournalLine.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :date, :date, allow_nil?: false, public?: true
    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :debit, :decimal,
      allow_nil?: false,
      public?: true,
      default: 0,
      constraints: [min: 0]

    attribute :credit, :decimal,
      allow_nil?: false,
      public?: true,
      default: 0,
      constraints: [min: 0]

    create_timestamp :inserted_at
  end
end
