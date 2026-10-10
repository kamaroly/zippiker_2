defmodule Zippiker.Extensibility.CustomFields do
  @moduledoc """
  Resource extension that makes a resource accept tenant-defined custom fields.

      use Ash.Resource, extensions: [Zippiker.Extensibility.CustomFields]

      custom_fields do
        entity :deal
      end

  It adds a `custom_fields` map attribute (a JSONB column) and a change that
  casts and validates submitted values against the organization's
  `Zippiker.Extensibility.CustomFieldDefinition`s on every create and update.
  Use `entity_from` instead of `entity` when the entity depends on an
  attribute value (e.g. a party's `kind`).
  """

  @custom_fields %Spark.Dsl.Section{
    name: :custom_fields,
    describe: "Configure tenant-defined custom fields.",
    schema: [
      entity: [
        type: :atom,
        doc: "The `Zippiker.Extensibility.Entity` value definitions are stored under."
      ],
      entity_from: [
        type: :atom,
        doc: "An attribute whose value is the entity, e.g. `:kind`."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@custom_fields],
    transformers: [Zippiker.Extensibility.CustomFields.Transformers.Setup]
end
