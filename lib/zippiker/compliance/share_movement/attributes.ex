defmodule Zippiker.Compliance.ShareMovement.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:allotment, :transfer_in, :transfer_out, :cancellation]
    end

    attribute :quantity, :integer, allow_nil?: false, public?: true
    attribute :date, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :consideration, :decimal, public?: true, constraints: [min: 0]
    attribute :certificate_number, :string, public?: true, constraints: [max_length: 40]
    attribute :notes, :string, public?: true, constraints: [max_length: 500]
    create_timestamp :inserted_at
  end
end
