defmodule Zippiker.Extensibility.CustomFieldDefinition.Validations.OptionsMatchType do
  @moduledoc "Select fields need at least one option."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    type = Ash.Changeset.get_attribute(changeset, :type)
    options = Ash.Changeset.get_attribute(changeset, :options) || []

    if type in Zippiker.Extensibility.FieldType.with_options() and options == [] do
      {:error, field: :options, message: "add at least one option"}
    else
      :ok
    end
  end
end
