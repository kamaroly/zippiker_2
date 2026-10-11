defmodule ZippikerWeb.WorkspaceController do
  @moduledoc """
  Session-level workspace actions LiveViews can't do: switching, invitation
  links, and workspace admins impersonating their team members.
  """
  use ZippikerWeb, :controller

  require Ash.Query

  import ZippikerWeb.LiveHelpers, only: [impersonation_allowed?: 2]

  alias Zippiker.Accounts.{Membership, User}

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

  @doc """
  A workspace owner or admin signs in as one of their members to see what
  they see (support, checking permissions). Owners can impersonate admins
  and members, admins only members; never super admins, never themselves,
  never while already impersonating. Logged to the audit trail.
  """
  def impersonate(conn, %{"organization_id" => organization_id, "user_id" => user_id}) do
    actor = conn.assigns[:current_user]

    with %User{} <- actor,
         nil <- get_session(conn, :impersonator_id),
         %{role: target_role, user: %User{super_admin?: false} = target} <-
           membership(organization_id, user_id),
         true <- target.id != actor.id,
         true <- impersonation_allowed?(role(actor, organization_id), target_role),
         {:ok, token, _claims} <- AshAuthentication.Jwt.token_for_user(target) do
      Zippiker.Platform.log_event!(
        %{
          action: :impersonation_started,
          summary: "Workspace admin started impersonating #{target.email}",
          organization_id: organization_id,
          target_user_id: target.id
        },
        actor: actor,
        authorize?: false
      )

      conn
      |> AshAuthentication.Plug.Helpers.store_in_session(
        Ash.Resource.put_metadata(target, :token, token)
      )
      |> put_session(:impersonator_id, actor.id)
      |> put_session(:impersonation_origin, organization_id)
      |> put_session(:organization_id, organization_id)
      |> put_flash(:info, "You're now seeing the workspace as #{target.email}.")
      |> redirect(to: ~p"/")
    else
      _ ->
        conn
        |> put_flash(:error, "You can't impersonate that person.")
        |> redirect(to: ~p"/settings/users")
    end
  end

  defp membership(organization_id, user_id) do
    Membership
    |> Ash.Query.filter(organization_id == ^organization_id and user_id == ^user_id)
    |> Ash.Query.load(:user)
    |> Ash.read_one!(authorize?: false)
  end

  defp role(%{super_admin?: true}, _organization_id), do: :owner

  defp role(actor, organization_id) do
    case membership(organization_id, actor.id) do
      %{role: role} -> role
      nil -> nil
    end
  end
end
