defmodule ZippikerWeb.Layouts do
  @moduledoc """
  Application layouts: the workspace shell with its sidebar, and a centered
  layout for onboarding.
  """
  use ZippikerWeb, :html

  embed_templates "layouts/*"

  # {key, label, icon, path, module} – module nil means always available.
  @nav [
    {:dashboard, "Dashboard", "hero-squares-2x2", "/", nil},
    {:leads, "Leads", "hero-inbox-arrow-down", "/leads", :crm},
    {:deals, "Deals", "hero-view-columns", "/deals", :crm},
    {:contacts, "Contacts", "hero-users", "/contacts", nil},
    {:companies, "Companies", "hero-building-office-2", "/companies", nil},
    {:tasks, "Tasks", "hero-check-circle", "/tasks", :crm}
  ]

  @sales_nav [
    {:quotes, "Quotes", "hero-document-text", "/quotes", :sales},
    {:sales_orders, "Orders", "hero-clipboard-document-check", "/orders", :sales},
    {:deliveries, "Delivery notes", "hero-truck", "/deliveries", :sales},
    {:invoices, "Invoices", "hero-banknotes", "/invoices", :sales},
    {:products, "Products", "hero-cube", "/products", :sales}
  ]

  @purchasing_nav [
    {:rfqs, "Requests for quotation", "hero-chat-bubble-left-ellipsis", "/rfqs", :purchasing},
    {:purchase_orders, "Purchase orders", "hero-shopping-cart", "/purchase-orders", :purchasing},
    {:goods_receipts, "Goods received", "hero-inbox-arrow-down", "/goods-receipts", :purchasing},
    {:bills, "Bills", "hero-document-minus", "/bills", :purchasing}
  ]

  @inventory_nav [
    {:stock, "Stock", "hero-archive-box", "/inventory", :inventory},
    {:stock_operations, "Movements", "hero-arrows-right-left", "/inventory/operations",
     :inventory},
    {:warehouses, "Warehouses", "hero-building-storefront", "/inventory/warehouses", :inventory}
  ]

  @hr_nav [
    {:employees, "Employees", "hero-identification", "/hr/employees", :hr},
    {:leave, "Leave", "hero-sun", "/hr/leave", :hr},
    {:org_chart, "Org chart", "hero-share", "/hr/org-chart", :hr},
    {:departments, "Departments", "hero-rectangle-group", "/hr/departments", :hr},
    {:leave_policies, "Leave policies", "hero-scale", "/hr/leave-policies", :hr},
    {:leave_types, "Leave types", "hero-calendar-days", "/hr/leave-types", :hr}
  ]

  @accounting_nav [
    {:accounting, "Overview", "hero-calculator", "/accounting", :accounting},
    {:journal, "Journal", "hero-book-open", "/accounting/journal", :accounting},
    {:accounts, "Chart of accounts", "hero-list-bullet", "/accounting/accounts", :accounting},
    {:reports, "Reports", "hero-chart-bar", "/accounting/reports", :accounting}
  ]

  @settings_nav [
    {:custom_fields, "Custom fields", "hero-adjustments-horizontal", "/settings/custom-fields",
     nil},
    {:pipeline, "Pipeline", "hero-queue-list", "/settings/pipeline", :crm},
    {:company, "Company details", "hero-building-library", "/settings/company", nil},
    {:taxes, "Taxes", "hero-receipt-percent", "/settings/taxes", :sales},
    {:workspace, "Workspace", "hero-cog-6-tooth", "/settings/workspace", nil},
    {:billing, "Plan & billing", "hero-credit-card", "/settings/billing", nil}
  ]

  @doc """
  The workspace shell.

      <Layouts.app flash={@flash} current_user={@current_user}
        current_organization={@current_organization} active={:deals}>
        ...
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, required: true
  attr :current_organization, :map, required: true
  attr :active, :atom, default: nil, doc: "the highlighted navigation item"
  attr :wide, :boolean, default: false, doc: "use the full width (e.g. the deal board)"
  slot :inner_block, required: true

  def app(assigns) do
    organization = assigns.current_organization
    visible = &Enum.filter(&1, fn item -> visible?(item, organization) end)

    assigns =
      assign(assigns,
        sections: [
          {nil, visible.(@nav)},
          {"Sales", visible.(@sales_nav)},
          {"Purchasing", visible.(@purchasing_nav)},
          {"Inventory", visible.(@inventory_nav)},
          {"People", visible.(@hr_nav)},
          {"Accounting", visible.(@accounting_nav)},
          {"Settings", visible.(@settings_nav)}
        ],
        impersonator: assigns.current_user.__metadata__[:impersonator],
        platform_access?: organization.__metadata__[:platform_access?] == true
      )

    ~H"""
    <div class="min-h-screen lg:pl-64">
      <%!-- Mobile top bar --%>
      <div class="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-surface/90 px-4 backdrop-blur lg:hidden">
        <button
          id="sidebar-open"
          type="button"
          class="rounded-lg p-1.5 text-ink-soft hover:bg-canvas"
          phx-click={
            JS.remove_class("-translate-x-full", to: "#sidebar") |> JS.show(to: "#sidebar-backdrop")
          }
          aria-label="Open menu"
        >
          <.icon name="hero-bars-3" class="size-5" />
        </button>
        <.brand />
      </div>

      <div
        id="sidebar-backdrop"
        class="fixed inset-0 z-30 hidden bg-ink/20 lg:hidden"
        phx-click={
          JS.add_class("-translate-x-full", to: "#sidebar") |> JS.hide(to: "#sidebar-backdrop")
        }
      />

      <aside
        id="sidebar"
        class="fixed inset-y-0 left-0 z-40 flex w-64 -translate-x-full flex-col border-r border-line bg-surface transition-transform duration-200 lg:translate-x-0"
      >
        <div class="flex h-16 items-center px-5"><.brand /></div>

        <details id="workspace-switcher" class="group relative mx-3 mb-3">
          <summary class="flex cursor-pointer list-none items-center gap-2.5 rounded-xl border border-line px-3 py-2 transition hover:border-line-strong [&::-webkit-details-marker]:hidden">
            <.avatar name={@current_organization.name} size="sm" square />
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-ink">{@current_organization.name}</p>
              <p class="text-xs text-muted">{@current_organization.currency} workspace</p>
            </div>
            <.icon name="hero-chevron-up-down-micro" class="size-4 text-muted" />
          </summary>
          <div class="absolute inset-x-0 top-full z-50 mt-1 rounded-xl border border-line bg-surface p-1 shadow-pop">
            <.link
              :for={membership <- @current_user.memberships}
              href={~p"/workspaces/#{membership.organization_id}/switch"}
              method="post"
              class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-ink-soft hover:bg-canvas hover:text-ink"
            >
              <.avatar name={membership.organization.name} size="xs" square />
              <span class="flex-1 truncate">{membership.organization.name}</span>
              <.icon
                :if={membership.organization_id == @current_organization.id}
                name="hero-check-micro"
                class="size-4 text-brand"
              />
            </.link>
            <.link
              navigate={~p"/onboarding?new=1"}
              class="mt-1 flex items-center gap-2 rounded-lg border-t border-line px-2 py-1.5 text-sm text-muted hover:bg-canvas hover:text-ink"
            >
              <.icon name="hero-plus-micro" class="size-4" /> New workspace
            </.link>
          </div>
        </details>

        <nav class="flex-1 space-y-0.5 overflow-y-auto px-3 py-2" aria-label="Main">
          <%= for {title, items} <- @sections, items != [] do %>
            <p
              :if={title}
              class="px-3 pt-6 pb-2 text-[11px] font-semibold tracking-wider text-muted uppercase"
            >
              {title}
            </p>
            <.nav_item
              :for={{key, label, icon, path, _module} <- items}
              active={@active == key}
              icon={icon}
              navigate={path}
            >
              {label}
            </.nav_item>
          <% end %>
        </nav>

        <div class="border-t border-line p-3">
          <div class="mb-2 space-y-0.5">
            <.nav_item active={@active == :help} icon="hero-question-mark-circle" navigate="/help">
              Help center
            </.nav_item>
            <.nav_item
              :if={@current_user.super_admin?}
              active={false}
              icon="hero-shield-check"
              navigate="/platform"
            >
              Platform admin
            </.nav_item>
          </div>
          <div class="mb-3 px-2"><.theme_toggle /></div>
          <div class="flex items-center gap-2.5 rounded-xl px-2 py-1.5">
            <.avatar name={Format.user_name(@current_user)} size="sm" />
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-ink">{Format.user_name(@current_user)}</p>
              <p class="truncate text-xs text-muted">{@current_user.email}</p>
            </div>
            <.link
              href={~p"/sign-out"}
              class="rounded-lg p-1.5 text-muted transition hover:bg-canvas hover:text-ink"
              title="Sign out"
            >
              <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" />
            </.link>
          </div>
        </div>
      </aside>

      <.platform_banner
        impersonator={@impersonator}
        platform_access?={@platform_access?}
        current_user={@current_user}
        current_organization={@current_organization}
      />

      <main class={[
        "animate-rise px-4 py-6 sm:px-8 sm:py-8",
        !@wide && "mx-auto max-w-7xl"
      ]}>
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp visible?({_key, _label, _icon, _path, nil}, _organization), do: true

  defp visible?({_key, _label, _icon, _path, module}, organization),
    do: ZippikerWeb.Modules.enabled?(organization, module)

  attr :impersonator, :any, required: true
  attr :platform_access?, :boolean, required: true
  attr :current_user, :map, required: true
  attr :current_organization, :map, required: true

  # Super admin context: impersonating someone, or inside a workspace they
  # don't belong to. Always visible so nobody forgets.
  defp platform_banner(assigns) do
    ~H"""
    <div
      :if={@impersonator || @platform_access?}
      id="platform-banner"
      class="sticky top-0 z-20 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 bg-ink px-4 py-2 text-center text-xs text-canvas"
    >
      <.icon name="hero-shield-exclamation-micro" class="size-4 text-brand" />
      <span :if={@impersonator}>
        You're signed in as <strong>{Format.user_name(@current_user)}</strong>
        (impersonated by {Format.user_name(@impersonator)}).
      </span>
      <span :if={!@impersonator}>
        Platform access to <strong>{@current_organization.name}</strong> — you act as an admin here.
      </span>
      <.link
        :if={@impersonator}
        id="stop-impersonating"
        href={~p"/platform/impersonation"}
        method="delete"
        class="rounded-md bg-canvas/15 px-2 py-0.5 font-semibold hover:bg-canvas/25"
      >
        Stop impersonating
      </.link>
      <.link
        :if={!@impersonator}
        id="leave-workspace"
        href={~p"/platform/access"}
        method="delete"
        class="rounded-md bg-canvas/15 px-2 py-0.5 font-semibold hover:bg-canvas/25"
      >
        Back to platform
      </.link>
    </div>
    """
  end

  @platform_nav [
    {:overview, "Overview", "/platform"},
    {:teams, "Workspaces", "/platform/teams"},
    {:users, "Users", "/platform/users"},
    {:plans, "Plans", "/platform/plans"},
    {:billing, "Billing", "/platform/billing"}
  ]

  @doc """
  The super admin shell: a dark top bar with tabs, distinct from workspaces
  so it's always obvious you're operating the platform.
  """
  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :active, :atom, default: nil
  slot :inner_block, required: true

  def platform(assigns) do
    assigns = assign(assigns, :nav, @platform_nav)

    ~H"""
    <div class="min-h-screen">
      <header class="sticky top-0 z-30 border-b border-line bg-surface/90 backdrop-blur">
        <div class="mx-auto flex h-14 max-w-7xl items-center gap-4 px-4 sm:px-8">
          <.brand />
          <span class="rounded-md bg-ink px-1.5 py-0.5 text-[11px] font-semibold tracking-wide text-canvas uppercase">
            Platform
          </span>
          <div class="flex-1" />
          <.link
            :if={@current_user.memberships != []}
            navigate={~p"/"}
            class="hidden text-sm text-muted hover:text-ink sm:block"
          >
            My workspace →
          </.link>
          <.avatar name={Format.user_name(@current_user)} size="sm" />
          <.link
            href={~p"/sign-out"}
            class="rounded-lg p-1.5 text-muted transition hover:bg-canvas hover:text-ink"
            title="Sign out"
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" />
          </.link>
        </div>
        <nav
          class="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-2 sm:px-6"
          aria-label="Platform"
        >
          <.link
            :for={{key, label, path} <- @nav}
            navigate={path}
            class={[
              "border-b-2 px-3 py-2.5 text-sm whitespace-nowrap transition-colors",
              @active == key && "border-brand font-semibold text-ink",
              @active != key && "border-transparent text-muted hover:text-ink"
            ]}
          >
            {label}
          </.link>
        </nav>
      </header>

      <main class="mx-auto max-w-7xl animate-rise px-4 py-6 sm:px-8 sm:py-8">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc "Centered single-card layout for onboarding."
  attr :flash, :map, required: true
  slot :inner_block, required: true

  def centered(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center px-4 py-12">
      <div class="mb-8"><.brand /></div>
      <div class="w-full max-w-md animate-rise">{render_slot(@inner_block)}</div>
      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
        @active && "bg-canvas font-semibold text-ink",
        !@active && "text-ink-soft hover:bg-canvas/70 hover:text-ink"
      ]}
    >
      <.icon
        name={@icon}
        class={[
          "size-[18px] transition-colors",
          if(@active, do: "text-brand", else: "text-muted group-hover:text-ink-soft")
        ]}
      />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def brand(assigns) do
    ~H"""
    <.link navigate={~p"/"} class="flex items-center gap-2">
      <span class="flex size-7 items-center justify-center rounded-lg bg-brand text-brand-ink shadow-card">
        <.icon name="hero-bolt-solid" class="size-4" />
      </span>
      <span class="text-[17px] font-bold tracking-tight text-ink">zippiker</span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>
    </div>
    """
  end

  @doc """
  Light / dark / system theme switch. See <head> in root.html.heex.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex w-full items-center rounded-lg bg-canvas p-0.5">
      <div class="absolute left-0.5 h-7 w-[calc((100%-4px)/3)] rounded-md bg-surface shadow-card transition-[left] [[data-theme=light]_&]:left-[calc((100%-4px)/3+2px)] [[data-theme=dark]_&]:left-[calc((100%-4px)*2/3+2px)] [[data-theme-source=system]_&]:!left-0.5" />
      <button
        :for={
          {theme, icon} <- [
            {"system", "hero-computer-desktop-micro"},
            {"light", "hero-sun-micro"},
            {"dark", "hero-moon-micro"}
          ]
        }
        class="relative flex h-7 flex-1 cursor-pointer items-center justify-center text-muted hover:text-ink"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme={theme}
        title={String.capitalize(theme)}
      >
        <.icon name={icon} class="size-4" />
      </button>
    </div>
    """
  end
end
