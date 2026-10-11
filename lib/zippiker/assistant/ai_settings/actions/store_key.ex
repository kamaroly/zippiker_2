defmodule Zippiker.Assistant.AiSettings.Actions.StoreKey do
  @moduledoc "Encrypts a newly given API key; a blank key keeps the stored one."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset |> Ash.Changeset.get_argument(:api_key) |> to_string() |> String.trim() do
      "" ->
        changeset

      key ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :encrypted_api_key,
          Zippiker.Assistant.Vault.encrypt(key)
        )
        |> Ash.Changeset.force_change_attribute(:key_hint, String.slice(key, -4, 4))
    end
  end
end
