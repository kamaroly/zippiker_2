defmodule ZippikerWeb.PortalController do
  @moduledoc """
  Portal invitation links: signed-in invitees (with the invited email)
  claim the access and land in the portal; others register or sign in
  first and come back.
  """
  use ZippikerWeb, :controller

  alias Zippiker.Accounts

  def join(conn, %{"token" => token}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_session(:return_to, ~p"/portal/join/#{token}")
        |> put_flash(
          :info,
          "Create a login (or sign in) with the invited email to open the portal."
        )
        |> redirect(to: ~p"/register")

      user ->
        with {:ok, access} <- Accounts.portal_invitation(token, actor: user),
             true <- to_string(access.email) == to_string(user.email),
             {:ok, access} <-
               Accounts.accept_portal_invitation(access,
                 actor: user,
                 tenant: access.organization_id
               ) do
          conn
          |> put_flash(:info, "Welcome to #{access.party_name}'s portal")
          |> redirect(to: ~p"/portal/#{access.id}")
        else
          false ->
            conn
            |> put_flash(
              :error,
              "This invitation is for another email address. Sign in with that one."
            )
            |> redirect(to: ~p"/")

          _ ->
            conn
            |> put_flash(:error, "This invitation link is no longer valid.")
            |> redirect(to: ~p"/")
        end
    end
  end
end
