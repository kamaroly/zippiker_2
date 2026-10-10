defmodule Zippiker.Extensibility.CustomFields.Changes.CastValues do
  @moduledoc """
  Casts submitted custom field values to their definition's type, enforces
  required fields and drops keys that have no active definition. Values of
  archived definitions already stored on the record are kept untouched.
  """
  use Ash.Resource.Change

  alias Zippiker.Extensibility.CustomFieldDefinition.Value
  alias Zippiker.Extensibility.CustomFields.Info

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :custom_fields) do
      cast(changeset)
    else
      changeset
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    if Ash.Changeset.changing_attribute?(changeset, :custom_fields) do
      {:not_atomic, "custom fields are validated against tenant definitions"}
    else
      {:ok, change(changeset, opts, context)}
    end
  end

  defp cast(changeset) do
    input =
      changeset
      |> Ash.Changeset.get_attribute(:custom_fields)
      |> Kernel.||(%{})
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    existing =
      if changeset.action_type == :update, do: changeset.data.custom_fields || %{}, else: %{}

    definitions =
      Zippiker.Extensibility.list_custom_fields!(
        Info.entity(changeset.resource, changeset),
        tenant: changeset.tenant,
        authorize?: false
      )

    {values, errors} =
      Enum.reduce(definitions, {existing, []}, fn definition, {values, errors} ->
        submitted? = Map.has_key?(input, definition.key)

        case Value.cast(definition, Map.get(input, definition.key), submitted?) do
          :keep -> {values, errors}
          {:ok, nil} -> {Map.delete(values, definition.key), errors}
          {:ok, value} -> {Map.put(values, definition.key, value), errors}
          {:error, message} -> {values, [message | errors]}
        end
      end)

    changeset = Ash.Changeset.force_change_attribute(changeset, :custom_fields, values)

    errors
    |> Enum.reverse()
    |> Enum.reduce(changeset, fn message, changeset ->
      Ash.Changeset.add_error(changeset, field: :custom_fields, message: message)
    end)
  end
end
