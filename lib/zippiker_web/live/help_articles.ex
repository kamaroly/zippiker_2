defmodule ZippikerWeb.HelpArticles do
  @moduledoc """
  End-user documentation. Each `help_articles/*.html.heex` file is one
  article (a function component); `articles/0` lists them for the help center.
  """
  use ZippikerWeb, :html

  embed_templates "help_articles/*"

  @articles [
    %{
      slug: "getting-started",
      title: "Getting started",
      section: "Basics",
      icon: "hero-rocket-launch",
      summary: "Set up your workspace, company details and team in ten minutes.",
      render: &__MODULE__.getting_started/1
    },
    %{
      slug: "contacts-and-companies",
      title: "Contacts & companies",
      section: "Basics",
      icon: "hero-users",
      summary: "One address book for customers, suppliers and everyone in between.",
      render: &__MODULE__.contacts_and_companies/1
    },
    %{
      slug: "leads-and-deals",
      title: "Leads, deals & tasks",
      section: "CRM",
      icon: "hero-funnel",
      summary: "Capture leads, move deals through your pipeline, never miss a follow-up.",
      render: &__MODULE__.leads_and_deals/1
    },
    %{
      slug: "quotes-and-invoices",
      title: "Quotes, orders & invoices",
      section: "Sales",
      icon: "hero-document-text",
      summary: "Products and taxes, quoting, sales orders, invoicing, collecting and printing.",
      render: &__MODULE__.quotes_and_invoices/1
    },
    %{
      slug: "purchasing",
      title: "Purchase orders & bills",
      section: "Purchasing",
      icon: "hero-shopping-cart",
      summary: "Order from suppliers, receive the goods, enter their bills and pay them.",
      render: &__MODULE__.purchasing/1
    },
    %{
      slug: "inventory",
      title: "Stock & warehouses",
      section: "Inventory",
      icon: "hero-archive-box",
      summary: "Track what's on your shelves, its value, and every movement in and out.",
      render: &__MODULE__.inventory/1
    },
    %{
      slug: "manufacturing",
      title: "Manufacturing",
      section: "Manufacturing",
      icon: "hero-wrench-screwdriver",
      summary: "Bills of materials, work centers, production orders and job cards.",
      render: &__MODULE__.manufacturing/1
    },
    %{
      slug: "people-and-leave",
      title: "People & leave",
      section: "HR",
      icon: "hero-user-group",
      summary: "Your team directory, reporting lines, departments and time off.",
      render: &__MODULE__.people_and_leave/1
    },
    %{
      slug: "approvals",
      title: "Approvals & workflows",
      section: "Approvals",
      icon: "hero-check-badge",
      summary: "Your approvals inbox, history, and who approves what in every module.",
      render: &__MODULE__.approvals/1
    },
    %{
      slug: "expenses",
      title: "Expense claims & approvals",
      section: "Expenses",
      icon: "hero-receipt-percent",
      summary: "Claim back what you spent, approval workflows, and paying people back.",
      render: &__MODULE__.expenses/1
    },
    %{
      slug: "accounting",
      title: "Accounting basics",
      section: "Accounting",
      icon: "hero-calculator",
      summary: "How your books fill themselves, recording expenses, journal entries and reports.",
      render: &__MODULE__.accounting/1
    },
    %{
      slug: "custom-fields",
      title: "Custom fields",
      section: "Customize",
      icon: "hero-adjustments-horizontal",
      summary: "Track the extra details your business needs, and filter by them.",
      render: &__MODULE__.custom_fields/1
    },
    %{
      slug: "team-and-billing",
      title: "Team, roles & billing",
      section: "Workspace",
      icon: "hero-credit-card",
      summary: "Invite people, choose who can do what, seats, plans and invoices.",
      render: &__MODULE__.team_and_billing/1
    },
    %{
      slug: "faq",
      title: "Questions & answers",
      section: "Help",
      icon: "hero-chat-bubble-left-right",
      summary: "Quick answers to the things people ask most.",
      render: &__MODULE__.faq/1
    }
  ]

  def articles, do: @articles

  def find(slug), do: Enum.find(@articles, &(&1.slug == slug))

  @doc "A tip / warning callout inside an article."
  attr :kind, :atom, default: :tip, values: [:tip, :warning]
  slot :inner_block, required: true

  def callout(assigns) do
    ~H"""
    <div class={["help-callout", @kind == :warning && "help-callout-warning"]}>
      <.icon
        name={if(@kind == :warning, do: "hero-exclamation-triangle", else: "hero-light-bulb")}
        class="mt-0.5 size-4 shrink-0"
      />
      <div>{render_slot(@inner_block)}</div>
    </div>
    """
  end
end
