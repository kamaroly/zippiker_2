defmodule Zippiker.Parties.Party.Changes.SetPersonName do
  @moduledoc "Keeps a person's `name` in sync with their first and last name."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    kind = Ash.Changeset.get_attribute(changeset, :kind)

    if kind == :person and
         (Ash.Changeset.changing_attribute?(changeset, :first_name) or
            Ash.Changeset.changing_attribute?(changeset, :last_name)) do
      name =
        [:first_name, :last_name]
        |> Enum.map(&Ash.Changeset.get_attribute(changeset, &1))
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" ")

      if name == "",
        do: Ash.Changeset.add_error(changeset, field: :first_name, message: "is required"),
        else: Ash.Changeset.force_change_attribute(changeset, :name, name)
    else
      changeset
    end
  end
end
