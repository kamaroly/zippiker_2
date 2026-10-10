defmodule ZippikerWeb.Platform.OverviewLive do
  @moduledoc "Super admin home: platform KPIs, newest workspaces and the audit log."
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Platform}

  @impl true
  def mount(_params, _session, socket) do
    actor = [actor: socket.assigns.current_user]

    {:ok,
     socket
     |> assign(:page_title, "Platform")
     |> assign(:overview, Platform.platform_overview!(actor))
     |> stream(:teams, Accounts.platform_organizations!(%{}, actor ++ [page: [limit: 6]]).results)
     |> stream(:events, Platform.list_audit_events!(%{}, actor ++ [page: [limit: 15]]).results)}
  end
end
