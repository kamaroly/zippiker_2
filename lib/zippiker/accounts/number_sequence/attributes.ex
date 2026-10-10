defmodule Zippiker.Accounts.NumberSequence.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :document_type, :atom, allow_nil?: false, public?: true
    attribute :year, :integer, allow_nil?: false, public?: true
    attribute :last_value, :integer, allow_nil?: false, public?: true, default: 0
    timestamps()
  end
end
