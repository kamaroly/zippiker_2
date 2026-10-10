defmodule Zippiker.Accounts.Invitation.Preparations.LoadPublicDetails do
  @moduledoc """
  Loads the workspace and inviter for the invitee, who isn't a member yet and
  so can't read them through normal policies. Only used on actions already
  restricted to the token holder or the invited email.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.after_action(query, fn _query, invitations ->
      Ash.load(invitations, [:organization, :invited_by], authorize?: false)
    end)
  end
end
