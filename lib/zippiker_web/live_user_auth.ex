defmodule ZippikerWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use ZippikerWeb, :verified_routes

  alias Zippiker.Accounts.{Organization, User}

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {ZippikerWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  # Requires a signed-in user with a workspace. Loads the user's memberships
  # once (policy checks reuse them) and assigns `current_organization`: the
  # one picked via `WorkspaceController.switch/2` (or, for super admins,
  # `PlatformController.access/2`), else the first. Pages of a module the
  # workspace doesn't have are refused.
  def on_mount(:live_workspace, params, session, socket) do
    with {:cont, socket} <- on_mount(:live_user_required, params, session, socket) do
      user = load_user(socket.assigns.current_user, session)

      case pick_workspace(user, session["organization_id"]) do
        nil ->
          to = if user.super_admin?, do: ~p"/platform", else: ~p"/onboarding"
          {:halt, Phoenix.LiveView.redirect(socket, to: to)}

        {organization, role} ->
          socket
          |> assign(current_user: user, current_organization: organization, current_role: role)
          |> require_module()
      end
    end
  end

  def on_mount(:live_super_admin, params, session, socket) do
    with {:cont, socket} <- on_mount(:live_user_required, params, session, socket) do
      user = load_user(socket.assigns.current_user, session)

      if user.super_admin? do
        {:cont, assign(socket, :current_user, user)}
      else
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
      end
    end
  end

  # While impersonating, the real super admin rides along as metadata so the
  # layout can show the "Stop impersonating" banner.
  defp load_user(user, session) do
    user = Ash.load!(user, [memberships: :organization], authorize?: false)

    with id when is_binary(id) <- session["impersonator_id"],
         {:ok, admin} <- Ash.get(User, id, authorize?: false) do
      Ash.Resource.put_metadata(user, :impersonator, admin)
    else
      _ -> user
    end
  end

  defp pick_workspace(user, chosen) do
    case Enum.find(user.memberships, &(&1.organization_id == chosen)) do
      %{organization: organization, role: role} ->
        {organization, role}

      nil ->
        platform_access(user, chosen) || first_workspace(user)
    end
  end

  # A super admin opening a workspace they don't belong to acts as an admin.
  defp platform_access(%{super_admin?: true}, id) when is_binary(id) do
    case Ash.get(Organization, id, authorize?: false) do
      {:ok, organization} ->
        {Ash.Resource.put_metadata(organization, :platform_access?, true), :admin}

      _ ->
        nil
    end
  end

  defp platform_access(_user, _id), do: nil

  defp first_workspace(%{memberships: [membership | _]}),
    do: {membership.organization, membership.role}

  defp first_workspace(_user), do: nil

  defp require_module(socket) do
    case ZippikerWeb.Modules.for_view(socket.view, socket.assigns[:live_action]) do
      nil ->
        {:cont, socket}

      key ->
        if ZippikerWeb.Modules.enabled?(socket.assigns.current_organization, key) do
          {:cont, socket}
        else
          {:halt,
           socket
           |> Phoenix.LiveView.put_flash(
             :error,
             "#{ZippikerWeb.Modules.name(key)} isn't enabled for this workspace."
           )
           |> Phoenix.LiveView.redirect(to: ~p"/")}
        end
    end
  end
end
