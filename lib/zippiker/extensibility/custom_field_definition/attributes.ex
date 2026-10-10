defmodule Zippiker.Extensibility.CustomFieldDefinition.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :entity, Zippiker.Extensibility.Entity do
      allow_nil? false
      public? true
    end

    attribute :key, :string do
      description "Stable storage key. Generated from the label and never changed."
      allow_nil? false
      public? true
      constraints max_length: 60, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :label, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 80
    end

    attribute :type, Zippiker.Extensibility.FieldType do
      allow_nil? false
      public? true
      default :text
    end

    attribute :options, {:array, :string} do
      description "Choices for select and multi-select fields."
      allow_nil? false
      public? true
      default []
    end

    attribute :help_text, :string do
      public? true
      constraints max_length: 200
    end

    attribute :required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :position, :integer do
      allow_nil? false
      public? true
      default 0
    end

    timestamps()
  end
end
