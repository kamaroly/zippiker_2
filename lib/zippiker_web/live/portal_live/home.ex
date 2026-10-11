defmodule ZippikerWeb.PortalLive.Home do
  @moduledoc "A person's customer/supplier portals; with just one, straight into it."
  use ZippikerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.portal_accesses do
      [access] -> {:ok, push_navigate(socket, to: ~p"/portal/#{access.id}")}
      _ -> {:ok, assign(socket, :page_title, "Your portals")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.portal flash={@flash} current_user={@current_user} accesses={@portal_accesses}>
      <.header>
        Your portals
        <:subtitle>Businesses that gave you access to your documents with them.</:subtitle>
      </.header>
      <div id="portals" class="grid gap-3 sm:grid-cols-2">
        <.link
          :for={access <- @portal_accesses}
          navigate={~p"/portal/#{access.id}"}
          class="flex items-center gap-3 rounded-2xl border border-line bg-surface p-4 shadow-card transition hover:-translate-y-0.5 hover:shadow-pop"
        >
          <.avatar name={access.organization.name} square />
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-semibold text-ink">{access.organization.name}</span>
            <span class="block truncate text-xs text-muted">
              {if access.kind == :customer, do: "Customer", else: "Supplier"} · {access.party_name}
            </span>
          </span>
          <.icon name="hero-chevron-right" class="size-4 text-muted" />
        </.link>
      </div>
    </Layouts.portal>
    """
  end
end
