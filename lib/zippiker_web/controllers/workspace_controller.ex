defmodule ZippikerWeb.WorkspaceController do
  @moduledoc "Session-level workspace actions LiveViews can't do: switching and invitation links."
  use ZippikerWeb, :controller

  @doc "Remembers the chosen workspace in the session (only if the user belongs to it)."
  def switch(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]

    member? =
      user &&
        Zippiker.Accounts.list_my_memberships!(actor: user)
        |> Enum.any?(&(&1.organization_id == id))

    if member? do
      conn |> put_session(:organization_id, id) |> redirect(to: ~p"/")
    else
      conn |> put_flash(:error, "Workspace not found") |> redirect(to: ~p"/")
    end
  end

  @doc "Invitation email link: signed-in users go to accept; others register first and come back."
  def invitation(conn, %{"token" => token}) do
    accept = ~p"/invitations/#{token}/accept"

    if conn.assigns[:current_user] do
      redirect(conn, to: accept)
    else
      conn
      |> put_session(:return_to, accept)
      |> put_flash(:info, "Create an account (or sign in) to join the workspace.")
      |> redirect(to: ~p"/register")
    end
  end
end
