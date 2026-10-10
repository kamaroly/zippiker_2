defmodule Zippiker.Extensibility.CustomFieldDefinition.Changes.GenerateKey do
  @moduledoc "Derives a snake_case storage key from the label, e.g. `Annual Budget` -> `annual_budget`."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    label = Ash.Changeset.get_attribute(changeset, :label)

    if is_binary(label) and is_nil(Ash.Changeset.get_attribute(changeset, :key)) do
      Ash.Changeset.force_change_attribute(changeset, :key, slug(label))
    else
      changeset
    end
  end

  defp slug(label) do
    key =
      label
      |> String.downcase()
      |> String.normalize(:nfd)
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")
      |> String.slice(0, 60)

    if key =~ ~r/^[a-z]/, do: key, else: "f_" <> key
  end
end
