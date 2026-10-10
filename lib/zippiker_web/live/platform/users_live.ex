defmodule ZippikerWeb.Platform.UsersLive do
  @moduledoc "Every user: search, impersonate, grant or revoke super admin."
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Platform}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Users")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""

    page =
      Accounts.platform_users!(
        %{query: query},
        actor: socket.assigns.current_user,
        page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]
      )

    {:noreply,
     socket
     |> assign(query: query, page: page)
     |> stream(:users, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: query_path(~p"/platform/users", %{q: query}))}
  end

  def handle_event("toggle_super_admin", %{"id" => id}, socket) do
    admin = socket.assigns.current_user

    if id == admin.id do
      {:noreply, put_flash(socket, :error, "You can't change your own access.")}
    else
      user = Accounts.get_user!(id, actor: admin)
      user = Accounts.set_super_admin!(user, !user.super_admin?, actor: admin)

      Platform.log_event!(
        %{
          action: :super_admin_changed,
          summary:
            "#{if user.super_admin?, do: "Granted", else: "Revoked"} super admin for #{user.email}",
          target_user_id: user.id
        },
        actor: admin
      )

      {:noreply,
       stream_insert(
         socket,
         :users,
         Ash.load!(user, [:display_name, :memberships_count], actor: admin)
       )}
    end
  end
end
