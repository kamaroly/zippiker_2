defmodule Zippiker.HR.ChecklistTemplate.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:onboarding, :offboarding]
    end

    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :default?, :boolean do
      description "Starts automatically on hiring (onboarding) or leaving (offboarding)."
      allow_nil? false
      public? true
      default false
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
