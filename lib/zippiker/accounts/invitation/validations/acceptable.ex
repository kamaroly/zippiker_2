defmodule Zippiker.Accounts.Invitation.Validations.Acceptable do
  @moduledoc "Only open, unexpired invitations for the actor's own email can be accepted."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, %{actor: actor}) do
    invitation = changeset.data

    cond do
      invitation.accepted_at ->
        {:error, message: "this invitation was already used"}

      DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt ->
        {:error, message: "this invitation has expired"}

      Ash.CiString.compare(invitation.email, actor.email) != :eq ->
        {:error, message: "this invitation was sent to #{invitation.email}"}

      true ->
        :ok
    end
  end

  def validate(_changeset, _opts, _context), do: {:error, message: "sign in to accept"}
end
