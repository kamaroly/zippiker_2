defmodule Zippiker.Accounts.Branch.Changes.UpcaseCode do
  @moduledoc "Branch codes are stored upper case."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :code) do
      code when is_binary(code) ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :code,
          code |> String.trim() |> String.upcase()
        )

      _ ->
        changeset
    end
  end

  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}
end
