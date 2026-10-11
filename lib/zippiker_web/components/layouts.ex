defmodule ZippikerWeb.Layouts do
  @moduledoc """
  Application layouts: the workspace shell with its sidebar, and a centered
  layout for onboarding.
  """
  use ZippikerWeb, :html

  embed_templates "layouts/*"

  # Sidebar entries are modules; their pages show as tabs across the top of the
  # page (like the platform panel). Pages: {key, label, path, module} – module
  # nil means always available; a module with no visible pages is hidden.
  @modules [
    {:home, "Dashboard", "hero-squares-2x2", [{:dashboard, "Dashboard", "/", nil}]},
    {:me, "My workspace", "hero-user-circle",
     [
       {:me, "Overview", "/me", :hr},
       {:my_tasks, "My tasks", "/me/tasks", :hr},
       {:my_profile, "My profile", "/me/profile", :hr}
     ]},
    {:crm, "CRM", "hero-funnel",
     [
       {:leads, "Leads", "/leads", :crm},
       {:deals, "Deals", "/deals", :crm},
       {:tasks, "Tasks", "/tasks", :crm}
     ]},
    {:directory, "Contacts", "hero-users",
     [
       {:contacts, "Contacts", "/contacts", nil},
       {:companies, "Companies", "/companies", nil}
     ]},
    {:sales, "Sales", "hero-document-text",
     [
       {:quotes, "Quotes", "/quotes", :sales},
       {:sales_orders, "Orders", "/orders", :sales},
       {:deliveries, "Delivery notes", "/deliveries", :sales},
       {:invoices, "Invoices", "/invoices", :sales},
       {:products, "Products", "/products", :sales}
     ]},
    {:purchasing, "Purchasing", "hero-shopping-cart",
     [
       {:rfqs, "Requests for quotation", "/rfqs", :purchasing},
       {:purchase_orders, "Purchase orders", "/purchase-orders", :purchasing},
       {:goods_receipts, "Goods received", "/goods-receipts", :purchasing},
       {:bills, "Bills", "/bills", :purchasing}
     ]},
    {:inventory, "Inventory", "hero-archive-box",
     [
       {:stock, "Stock", "/inventory", :inventory},
       {:stock_operations, "Movements", "/inventory/operations", :inventory},
       {:warehouses, "Warehouses", "/inventory/warehouses", :inventory}
     ]},
    {:manufacturing, "Manufacturing", "hero-wrench-screwdriver",
     [
       {:production_orders, "Production orders", "/manufacturing/orders", :manufacturing},
       {:boms, "Bills of materials", "/manufacturing/boms", :manufacturing},
       {:work_centers, "Work centers", "/manufacturing/work-centers", :manufacturing}
     ]},
    {:hr, "People", "hero-user-group",
     [
       {:employees, "Employees", "/hr/employees", :hr},
       {:checklists, "On/offboarding", "/hr/checklists", :hr},
       {:leave, "Leave", "/hr/leave", :hr},
       {:leave_claims, "Leave claims", "/hr/leave-claims", :hr},
       {:org_chart, "Org chart", "/hr/org-chart", :hr},
       {:departments, "Departments", "/hr/departments", :hr},
       {:leave_policies, "Leave policies", "/hr/leave-policies", :hr},
       {:leave_types, "Leave types", "/hr/leave-types", :hr},
       {:holidays, "Public holidays", "/hr/holidays", :hr},
       {:checklist_templates, "Checklists", "/hr/checklist-templates", :hr}
     ]},
    {:expenses, "Expenses", "hero-receipt-percent",
     [
       {:my_expenses, "My claims", "/expenses", :expenses},
       {:all_expenses, "All claims", "/expenses/all", :expenses},
       {:expense_categories, "Categories", "/expenses/categories", :expenses}
     ]},
    {:accounting, "Accounting", "hero-calculator",
     [
       {:accounting, "Overview", "/accounting", :accounting},
       {:journal, "Journal", "/accounting/journal", :accounting},
       {:accounts, "Chart of accounts", "/accounting/accounts", :accounting},
       {:reports, "Reports", "/accounting/reports", :accounting}
     ]},
    {:approvals, "Approvals", "hero-check-badge",
     [
       {:approval_inbox, "Inbox", "/approvals", nil},
       {:change_requests, "Change requests", "/approvals/changes", nil},
       {:approval_history, "History", "/approvals/history", nil},
       {:approval_workflows, "Workflows", "/approvals/workflows", nil},
       {:approval_groups, "Approval groups", "/approvals/groups", nil}
     ]},
    {:settings, "Settings", "hero-cog-6-tooth",
     [
       {:company, "Company details", "/settings/company", nil},
       {:workspace, "Workspace", "/settings/workspace", nil},
       {:branches, "Branches", "/settings/branches", nil},
       {:billing, "Plan & billing", "/settings/billing", nil},
       {:custom_fields, "Custom fields", "/settings/custom-fields", nil},
       {:pipeline, "Pipeline", "/settings/pipeline", :crm},
       {:taxes, "Taxes", "/settings/taxes", :sales}
     ]}
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
    sections = sections(organization)

    assigns =
      assign(assigns,
        sections: sections,
        current:
          Enum.find(sections, fn section ->
            Enum.any?(section.pages, &(elem(&1, 0) == assigns.active))
          end),
        impersonator: assigns.current_user.__metadata__[:impersonator],
        platform_access?: organization.__metadata__[:platform_access?] == true
      )

    ~H"""
    <div class="min-h-screen lg:pl-64">
      <%!-- Top bar: menu (mobile), then help, platform admin and the user menu on the right --%>
      <div
        id="top-bar"
        class="sticky top-0 z-30 flex h-14 items-center gap-2 border-b border-line bg-surface/90 px-4 backdrop-blur sm:px-6"
      >
        <button
          id="sidebar-open"
          type="button"
          phx-click={
            JS.remove_class("-translate-x-full", to: "#sidebar") |> JS.show(to: "#sidebar-backdrop")
          }
          aria-label="Open menu"
          class="rounded-lg p-1.5 text-ink-soft hover:bg-canvas lg:hidden"
        >
          <.icon name="hero-bars-3" class="size-5" />
        </button>
        <div class="lg:hidden"><.brand /></div>
        <div class="ml-auto flex items-center gap-1">
          <.link
            navigate="/help"
            id="top-help"
            class={[
              "flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-sm transition hover:bg-canvas hover:text-ink",
              if(@active == :help, do: "text-ink", else: "text-ink-soft")
            ]}
            title="Help center"
          >
            <.icon name="hero-question-mark-circle" class="size-5" />
            <span class="hidden sm:inline">Help</span>
          </.link>
          <.link
            :if={@current_user.super_admin?}
            navigate="/platform"
            id="top-platform"
            class="flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-sm text-ink-soft transition hover:bg-canvas hover:text-ink"
            title="Platform admin"
          >
            <.icon name="hero-shield-check" class="size-5" />
            <span class="hidden sm:inline">Platform admin</span>
          </.link>
          <.user_menu current_user={@current_user} />
        </div>
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
        <div class="flex h-14 items-center border-b border-line px-5"><.brand /></div>

        <details id="workspace-switcher" class="group relative mx-3 my-3">
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
          <.nav_item
            :for={section <- @sections}
            id={"nav-#{section.key}"}
            active={@current && @current.key == section.key}
            icon={section.icon}
            navigate={section.path}
            class={section.key == :settings && "mt-4"}
          >
            {section.label}
          </.nav_item>
        </nav>
      </aside>

      <.platform_banner
        impersonator={@impersonator}
        platform_access?={@platform_access?}
        current_user={@current_user}
        current_organization={@current_organization}
      />

      <nav
        :if={@current && length(@current.pages) > 1}
        id="module-tabs"
        class="border-b border-line bg-surface"
        aria-label={@current.label}
      >
        <div class={[
          "flex items-center gap-1 overflow-x-auto px-2 sm:px-6",
          !@wide && "mx-auto max-w-7xl"
        ]}>
          <span class="mr-3 hidden shrink-0 items-center gap-2 pl-2 text-sm font-semibold text-ink sm:flex">
            <.icon name={@current.icon} class="size-4 text-brand" /> {@current.label}
          </span>
          <.link
            :for={{key, label, path, _module} <- @current.pages}
            navigate={path}
            id={"tab-#{key}"}
            class={[
              "border-b-2 px-3 py-3 text-sm whitespace-nowrap transition-colors",
              @active == key && "border-brand font-semibold text-ink",
              @active != key && "border-transparent text-muted hover:text-ink"
            ]}
          >
            {label}
          </.link>
        </div>
      </nav>

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

  # Modules with the pages this workspace can see; the sidebar links to the first.
  defp sections(organization) do
    for {key, label, icon, pages} <- @modules,
        pages = Enum.filter(pages, &visible?(&1, organization)),
        pages != [] do
      %{key: key, label: label, icon: icon, pages: pages, path: pages |> hd() |> elem(2)}
    end
  end

  defp visible?({_key, _label, _path, nil}, _organization), do: true

  defp visible?({_key, _label, _path, module}, organization),
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
      class="sticky top-14 z-20 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 bg-ink px-4 py-2 text-center text-xs text-canvas"
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

  @doc "The customer/supplier portal shell: the team, the person's portals and their menu."
  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :access, :map, default: nil, doc: "the portal being shown"
  attr :accesses, :list, default: []
  slot :inner_block, required: true

  def portal(assigns) do
    ~H"""
    <div class="min-h-screen bg-canvas">
      <header class="sticky top-0 z-30 border-b border-line bg-surface/90 backdrop-blur">
        <div class="mx-auto flex h-14 max-w-5xl items-center gap-3 px-4 sm:px-6">
          <.link navigate={~p"/portal"} class="flex items-center gap-2">
            <.avatar :if={@access} name={@access.organization.name} size="sm" square />
            <span class="text-sm font-semibold text-ink">
              {if @access, do: @access.organization.name, else: "Your portals"}
            </span>
          </.link>
          <span :if={@access} class="hidden text-xs text-muted sm:inline">
            {if @access.kind == :customer, do: "Customer portal", else: "Supplier portal"} · {@access.party_name}
          </span>
          <div class="ml-auto flex items-center gap-1">
            <.link
              :if={length(@accesses) > 1}
              navigate={~p"/portal"}
              class="rounded-lg px-2.5 py-1.5 text-sm text-ink-soft hover:bg-canvas hover:text-ink"
            >
              Switch portal
            </.link>
            <.user_menu current_user={@current_user} />
          </div>
        </div>
      </header>
      <main class="animate-rise mx-auto max-w-5xl px-4 py-6 sm:px-6 sm:py-8">
        {render_slot(@inner_block)}
      </main>
      <.flash_group flash={@flash} />
    </div>
    """
  end

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
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      id={@id}
      class={[
        @class,
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

  @doc "The signed-in user's menu (top right): who you are, theme, sign out."
  attr :current_user, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <details id="user-menu" class="group relative">
      <summary class="flex cursor-pointer list-none items-center gap-2 rounded-xl px-1.5 py-1 transition hover:bg-canvas [&::-webkit-details-marker]:hidden">
        <.avatar name={Format.user_name(@current_user)} size="sm" />
        <span class="hidden max-w-36 truncate text-sm font-medium text-ink md:inline">
          {Format.user_name(@current_user)}
        </span>
        <.icon
          name="hero-chevron-down-micro"
          class="size-4 text-muted transition group-open:rotate-180"
        />
      </summary>
      <div class="absolute right-0 top-full z-50 mt-2 w-64 rounded-xl border border-line bg-surface p-2 shadow-pop">
        <div class="px-2 py-1.5">
          <p class="truncate text-sm font-semibold text-ink">{Format.user_name(@current_user)}</p>
          <p class="truncate text-xs text-muted">{@current_user.email}</p>
        </div>
        <div class="my-2 px-2"><.theme_toggle /></div>
        <.link
          href={~p"/sign-out"}
          id="sign-out"
          class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-ink-soft hover:bg-canvas hover:text-ink"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Sign out
        </.link>
      </div>
    </details>
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
