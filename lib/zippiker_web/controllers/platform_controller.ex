defmodule ZippikerWeb.PlatformController do
  @moduledoc """
  Session-level super admin actions: impersonating a user (and stopping),
  and opening any workspace. Every action is written to the audit log.
  """
  use ZippikerWeb, :controller

  alias Zippiker.Accounts.User
  alias Zippiker.Platform

  plug :require_super_admin when action in [:impersonate, :access]

  @doc "Signs in as another (non super admin) user, remembering who we really are."
  def impersonate(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    with {:ok, target} <- Ash.get(User, id, authorize?: false),
         false <- target.super_admin?,
         {:ok, token, _claims} <- AshAuthentication.Jwt.token_for_user(target) do
      log(admin, :impersonation_started, "Started impersonating #{target.email}",
        target_user_id: target.id
      )

      conn
      |> AshAuthentication.Plug.Helpers.store_in_session(
        Ash.Resource.put_metadata(target, :token, token)
      )
      |> put_session(:impersonator_id, admin.id)
      |> delete_session(:impersonation_origin)
      |> delete_session(:organization_id)
      |> put_flash(:info, "You're now signed in as #{target.email}.")
      |> redirect(to: ~p"/")
    else
      _ ->
        conn
        |> put_flash(:error, "That user can't be impersonated.")
        |> redirect(to: ~p"/platform/users")
    end
  end

  @doc """
  Returns to the impersonator's own session: super admins go back to the
  platform panel, workspace admins to their workspace's settings.
  """
  def stop_impersonating(conn, _params) do
    origin = get_session(conn, :impersonation_origin)

    with id when is_binary(id) <- get_session(conn, :impersonator_id),
         {:ok, admin} <- Ash.get(User, id, authorize?: false),
         true <- admin.super_admin? or is_binary(origin),
         {:ok, token, _claims} <- AshAuthentication.Jwt.token_for_user(admin) do
      impersonated = conn.assigns[:current_user]

      Platform.log_event!(
        %{
          action: :impersonation_stopped,
          summary: "Stopped impersonating #{impersonated && impersonated.email}",
          target_user_id: impersonated && impersonated.id,
          organization_id: origin
        },
        actor: admin,
        authorize?: false
      )

      conn =
        conn
        |> AshAuthentication.Plug.Helpers.store_in_session(
          Ash.Resource.put_metadata(admin, :token, token)
        )
        |> delete_session(:impersonator_id)
        |> delete_session(:impersonation_origin)

      if is_binary(origin) do
        conn |> put_session(:organization_id, origin) |> redirect(to: ~p"/settings/users")
      else
        conn |> delete_session(:organization_id) |> redirect(to: ~p"/platform/users")
      end
    else
      _ -> redirect(conn, to: ~p"/")
    end
  end

  @doc "Opens a workspace the super admin isn't a member of (acting as admin)."
  def access(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    case Zippiker.Accounts.get_organization(id, actor: admin) do
      {:ok, organization} ->
        log(admin, :workspace_accessed, "Opened #{organization.name}",
          organization_id: organization.id
        )

        conn |> put_session(:organization_id, organization.id) |> redirect(to: ~p"/")

      _ ->
        conn |> put_flash(:error, "Workspace not found") |> redirect(to: ~p"/platform/teams")
    end
  end

  @doc "Leaves a workspace opened with `access/2`."
  def leave(conn, _params) do
    conn |> delete_session(:organization_id) |> redirect(to: ~p"/platform/teams")
  end

  defp require_super_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{super_admin?: true} -> conn
      _ -> conn |> put_flash(:error, "Not allowed") |> redirect(to: ~p"/") |> halt()
    end
  end

  defp log(admin, action, summary, attrs) do
    Platform.log_event!(
      Map.merge(%{action: action, summary: summary}, Map.new(attrs)),
      actor: admin
    )
  end
end
