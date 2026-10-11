defmodule Zippiker.Compliance.Resolution.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :text, :string, allow_nil?: false, public?: true, constraints: [max_length: 5_000]

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :ordinary
      constraints one_of: [:ordinary, :special, :board]
    end

    attribute :passed?, :boolean, allow_nil?: false, public?: true, default: true
  end
end
