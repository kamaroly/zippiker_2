defmodule Zippiker.Accounts.PortalAccess.Senders.SendInvitation do
  @moduledoc "The email inviting a customer or supplier contact to the portal."
  use ZippikerWeb, :verified_routes

  import Swoosh.Email

  alias Zippiker.Mailer

  def send(access) do
    organization = Zippiker.Accounts.get_organization!(access.organization_id, authorize?: false)
    url = url(~p"/portal/join/#{access.token}")

    what =
      if access.kind == :customer,
        do: "quotes, orders and invoices",
        else: "requests for quotation, purchase orders and payments"

    new()
    |> from({"Zippiker", "noreply@zippiker.com"})
    |> to(to_string(access.email))
    |> subject("#{organization.name} invited you to their #{access.kind} portal")
    |> html_body("""
    <p>Hello,</p>
    <p>#{organization.name} gave you access to their portal for <strong>#{access.party_name}</strong>,
    where you can see your #{what}.</p>
    <p><a href="#{url}">Open the portal</a></p>
    <p>If you don't have a Zippiker login yet, create one with this email address.</p>
    """)
    |> Mailer.deliver()
  end
end
