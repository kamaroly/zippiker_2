defmodule Zippiker.Parties.Party.Changes.AddRole do
  @moduledoc "Adds a role to a party if it doesn't have it yet."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    role = Ash.Changeset.get_argument(changeset, :role)
    roles = changeset.data.roles || []

    if role in roles,
      do: changeset,
      else: Ash.Changeset.change_attribute(changeset, :roles, roles ++ [role])
  end

  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}
end
