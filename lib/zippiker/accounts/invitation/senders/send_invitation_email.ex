defmodule Zippiker.Accounts.Invitation.Senders.SendInvitationEmail do
  @moduledoc "Delivers the invitation email with its accept link."
  use ZippikerWeb, :verified_routes

  import Swoosh.Email

  alias Zippiker.Mailer

  def send(invitation, inviter) do
    url = url(~p"/invitations/#{invitation.token}")
    inviter_name = (inviter && (inviter.name || to_string(inviter.email))) || "A teammate"

    new()
    |> from({"Zippiker", "noreply@zippiker.com"})
    |> to(to_string(invitation.email))
    |> subject("#{inviter_name} invited you to #{invitation.organization.name} on Zippiker")
    |> html_body("""
    <p>#{inviter_name} invited you to join <strong>#{invitation.organization.name}</strong> on Zippiker.</p>
    <p><a href="#{url}">Accept the invitation</a></p>
    <p>This link expires in 14 days. If you weren't expecting it, you can ignore this email.</p>
    """)
    |> text_body("""
    #{inviter_name} invited you to join #{invitation.organization.name} on Zippiker.
    Accept the invitation: #{url}
    """)
    |> Mailer.deliver!()
  end
end
