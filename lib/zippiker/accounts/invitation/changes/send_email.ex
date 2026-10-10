defmodule Zippiker.Accounts.Invitation.Changes.SendEmail do
  @moduledoc "Emails the invitation link once the invitation is stored."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      invitation = Ash.load!(invitation, :organization, authorize?: false)
      Zippiker.Accounts.Invitation.Senders.SendInvitationEmail.send(invitation, context.actor)
      {:ok, invitation}
    end)
  end
end
