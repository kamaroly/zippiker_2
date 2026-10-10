defmodule Zippiker.Extensibility.CustomFieldDefinition.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Extensibility.CustomFieldDefinition.{Changes, Validations}

  actions do
    defaults [:read, :destroy]

    read :for_entity do
      argument :entity, Zippiker.Extensibility.Entity, allow_nil?: false
      filter expr(entity == ^arg(:entity))
      prepare build(sort: [position: :asc, inserted_at: :asc])
    end

    create :create do
      primary? true
      accept [:entity, :label, :type, :options, :help_text, :required?, :position]
      change Changes.GenerateKey
      change Changes.NormalizeOptions
      validate Validations.OptionsMatchType
    end

    update :update do
      primary? true
      # `key`, `entity` and `type` are immutable: changing them would orphan stored values.
      accept [:label, :options, :help_text, :required?, :position]
      require_atomic? false
      change Changes.NormalizeOptions
      validate Validations.OptionsMatchType
    end
  end
end
