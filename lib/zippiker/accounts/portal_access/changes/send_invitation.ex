defmodule Zippiker.Accounts.PortalAccess.Changes.SendInvitation do
  @moduledoc "Emails the portal invitation link after it's saved."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, access ->
      Zippiker.Accounts.PortalAccess.Senders.SendInvitation.send(access)
      {:ok, access}
    end)
  end
end
