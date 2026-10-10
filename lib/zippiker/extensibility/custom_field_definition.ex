defmodule Zippiker.Extensibility.CustomFieldDefinition do
  @moduledoc """
  An organization-defined field for one `Zippiker.Extensibility.Entity`.
  Values live in the target record's `custom_fields` JSONB column, keyed by `key`.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Extensibility,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshArchival.Resource],
    fragments: [
      Zippiker.Extensibility.CustomFieldDefinition.Attributes,
      Zippiker.Extensibility.CustomFieldDefinition.Relationships,
      Zippiker.Extensibility.CustomFieldDefinition.Actions,
      Zippiker.Extensibility.CustomFieldDefinition.Policies
    ]

  postgres do
    table "custom_field_definitions"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_key: "archived_at IS NULL"

    references do
      reference :organization, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_key, [:entity, :key], where: expr(is_nil(archived_at))
  end
end
