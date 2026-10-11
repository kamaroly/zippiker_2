defmodule Zippiker.Accounts.PortalAccess.Changes.Prepare do
  @moduledoc "A secret token for the invitation link."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :token,
      Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    )
  end
end
