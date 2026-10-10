defmodule Zippiker.Accounts.Invitation.Changes.Prepare do
  @moduledoc "Generates the secret token and a 14 day expiry."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(
      :token,
      :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
    )
    |> Ash.Changeset.force_change_attribute(
      :expires_at,
      DateTime.add(DateTime.utc_now(), 14, :day)
    )
  end
end
