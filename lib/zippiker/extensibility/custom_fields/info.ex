defmodule Zippiker.Extensibility.CustomFields.Info do
  @moduledoc "Introspection for `Zippiker.Extensibility.CustomFields`."
  use Spark.InfoGenerator,
    extension: Zippiker.Extensibility.CustomFields,
    sections: [:custom_fields]

  @doc "Resolves the custom-field entity for a record or changeset."
  def entity(resource, record_or_changeset) do
    case custom_fields_entity(resource) do
      {:ok, entity} ->
        entity

      :error ->
        {:ok, attribute} = custom_fields_entity_from(resource)
        value(record_or_changeset, attribute)
    end
  end

  defp value(%Ash.Changeset{} = changeset, attribute),
    do: Ash.Changeset.get_attribute(changeset, attribute)

  defp value(record, attribute), do: Map.get(record, attribute)
end
