defmodule Zippiker.Extensibility.CustomFieldDefinition.Changes.NormalizeOptions do
  @moduledoc "Trims options, removes blanks and duplicates."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :options) do
      options =
        changeset
        |> Ash.Changeset.get_attribute(:options)
        |> List.wrap()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()

      Ash.Changeset.force_change_attribute(changeset, :options, options)
    else
      changeset
    end
  end
end
