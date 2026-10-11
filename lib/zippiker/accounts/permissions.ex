defmodule Zippiker.Accounts.Permissions do
  @moduledoc """
  What members can be allowed to do, as permissions grouped by area
  ("Create and edit invoices", "Void invoices", "See Accounting"...), and the
  built-in roles made of them.

  Each action permission lists the Ash actions it covers. Enforcement:

    * `Checks.Permitted` runs before every create/update/destroy/generic
      action of the covered resources: a plain member needs the permission.
    * `Checks.ActorIsAdmin` also passes for a member holding the permission
      of the action being run, so a role can open up admin-only actions
      (approving bills, managing employees...).
    * Actions anyone may do for themselves (requesting leave, logging their
      own time...) stay open; their permission lets the member do them for
      anyone. Which actions those are is read from the resource policies.

  `view.*` permissions decide which modules show up for a member.
  Owners and admins have every permission. Actions not listed here
  (internal postings, numbering...) aren't restricted by roles.
  """

  alias Zippiker.Accounting.{Account, JournalEntry, JournalLine, Ledger}
  alias Zippiker.Accounts.{Branch, Invitation, LegalEntity, Membership, PortalAccess, Role}
  alias Zippiker.Catalog.{Product, TaxRate}
  alias Zippiker.Compliance
  alias Zippiker.Crm.{Activity, Deal, Lead, Pipeline, Stage, Task}
  alias Zippiker.Expenses.{ExpenseCategory, ExpenseClaim, ExpenseItem}
  alias Zippiker.Extensibility.CustomFieldDefinition
  alias Zippiker.HR
  alias Zippiker.Inventory.{StockMovement, StockOperation, Warehouse}

  alias Zippiker.Manufacturing.{
    BillOfMaterials,
    BomComponent,
    BomOperation,
    ProductionOrder,
    WorkCenter
  }

  alias Zippiker.Parties.{Address, Party}
  alias Zippiker.Purchasing.{Bill, BillLine, BillPayment, GoodsReceipt, GoodsReceiptLine}
  alias Zippiker.Purchasing.{PurchaseOrder, PurchaseOrderLine, Rfq, RfqLine}
  alias Zippiker.Sales.{Delivery, DeliveryLine, Invoice, InvoiceLine, Payment, Quote, QuoteLine}
  alias Zippiker.Sales.{SalesOrder, SalesOrderLine}
  alias Zippiker.Workflow.{ApprovalGroup, ApprovalGroupMember, ApprovalStep, ApprovalWorkflow}

  @crud [:create, :update, :destroy]

  @sections [
    {:contacts, "Contacts", nil},
    {:crm, "CRM", :crm},
    {:sales, "Sales", :sales},
    {:purchasing, "Purchasing", :purchasing},
    {:inventory, "Inventory", :inventory},
    {:manufacturing, "Manufacturing", :manufacturing},
    {:hr, "People", :hr},
    {:expenses, "Expenses", :expenses},
    {:accounting, "Accounting", :accounting},
    {:reports, "Reports", nil},
    {:compliance, "Company secretarial", :compliance},
    {:approvals, "Approvals", nil},
    {:settings, "Settings and team", nil}
  ]

  # {key, section, label, [{resource, actions}]}
  @permissions [
    # Contacts
    {"view.contacts", :contacts, "See contacts and companies", []},
    {"contacts.manage", :contacts, "Add and edit contacts and companies",
     [{Party, [:create, :update, :add_role]}, {Address, @crud}]},
    {"contacts.delete", :contacts, "Delete contacts and companies", [{Party, [:destroy]}]},
    {"custom_fields.manage", :contacts, "Manage custom fields", [{CustomFieldDefinition, @crud}]},

    # CRM
    {"view.crm", :crm, "See CRM (leads, deals, tasks)", []},
    {"leads.manage", :crm, "Add and edit leads", [{Lead, @crud}]},
    {"leads.convert", :crm, "Convert leads to deals", [{Lead, [:convert]}]},
    {"deals.manage", :crm, "Add, edit and move deals",
     [{Deal, [:create, :update, :move, :destroy]}]},
    {"tasks.manage", :crm, "Add, complete and reassign tasks",
     [{Task, [:create, :update, :complete, :reopen, :reassign, :destroy]}]},
    {"activities.manage", :crm, "Log calls, emails, meetings and notes",
     [{Activity, [:create, :destroy, :reassign]}]},
    {"pipeline.manage", :crm, "Set up pipelines and stages", [{Pipeline, @crud}, {Stage, @crud}]},

    # Sales
    {"view.sales", :sales, "See Sales (quotes, orders, invoices)", []},
    {"quotes.manage", :sales, "Create, edit and send quotes",
     [{Quote, [:create, :update, :set_totals, :mark_sent, :reopen, :destroy]}, {QuoteLine, @crud}]},
    {"quotes.decide", :sales, "Mark quotes accepted or declined", [{Quote, [:accept, :decline]}]},
    {"sales_orders.manage", :sales, "Create, edit and confirm sales orders",
     [
       {SalesOrder, [:create, :from_quote, :update, :set_totals, :confirm]},
       {SalesOrderLine, @crud}
     ]},
    {"sales_orders.cancel", :sales, "Cancel sales orders", [{SalesOrder, [:cancel]}]},
    {"deliveries.manage", :sales, "Deliver goods and confirm delivery notes",
     [
       {SalesOrder, [:deliver, :mark_delivered]},
       {SalesOrderLine, [:set_delivered]},
       {Delivery, [:record, :confirm, :update, :cancel]},
       {DeliveryLine, [:create]}
     ]},
    {"invoices.create", :sales, "Create and edit draft invoices",
     [
       {Invoice, [:create, :from_quote, :from_sales_order, :update, :set_totals, :destroy]},
       {InvoiceLine, @crud}
     ]},
    {"invoices.issue", :sales, "Issue invoices", [{Invoice, [:issue]}]},
    {"invoices.void", :sales, "Void invoices", [{Invoice, [:void]}]},
    {"payments.record", :sales, "Record customer payments",
     [{Payment, [:create]}, {Invoice, [:apply_payments]}]},
    {"payments.delete", :sales, "Delete customer payments", [{Payment, [:destroy]}]},
    {"products.manage", :sales, "Add and edit products and prices",
     [{Product, [:create, :update, :destroy, :set_average_cost]}]},
    {"taxes.manage", :sales, "Manage tax rates", [{TaxRate, @crud}]},
    {"portal.manage", :sales, "Invite customers and suppliers to the portal",
     [{PortalAccess, [:invite, :revoke]}]},

    # Purchasing
    {"view.purchasing", :purchasing, "See Purchasing (RFQs, orders, bills)", []},
    {"rfqs.manage", :purchasing, "Create, edit and send requests for quotation",
     [{Rfq, [:create, :update, :set_totals, :mark_sent, :mark_quoted, :reopen]}, {RfqLine, @crud}]},
    {"rfqs.decide", :purchasing, "Accept or decline supplier quotes",
     [{Rfq, [:accept, :decline]}]},
    {"purchase_orders.manage", :purchasing, "Create, edit and place purchase orders",
     [
       {PurchaseOrder, [:create, :from_rfq, :update, :set_totals, :mark_ordered, :acknowledge]},
       {PurchaseOrderLine, @crud}
     ]},
    {"purchase_orders.cancel", :purchasing, "Cancel purchase orders",
     [{PurchaseOrder, [:cancel]}]},
    {"goods.receive", :purchasing, "Receive goods (GRNs)",
     [
       {PurchaseOrder, [:receive]},
       {PurchaseOrderLine, [:set_received]},
       {GoodsReceipt, [:record, :cancel]},
       {GoodsReceiptLine, [:create]}
     ]},
    {"bills.create", :purchasing, "Enter and edit supplier bills",
     [
       {Bill, [:create, :from_purchase_order, :update, :set_totals, :destroy]},
       {BillLine, @crud}
     ]},
    {"bills.approve", :purchasing, "Approve bills", [{Bill, [:approve]}]},
    {"bills.void", :purchasing, "Void bills", [{Bill, [:void]}]},
    {"bill_payments.record", :purchasing, "Pay suppliers",
     [{BillPayment, [:create]}, {Bill, [:apply_payments]}]},
    {"bill_payments.delete", :purchasing, "Delete supplier payments",
     [{BillPayment, [:destroy]}]},

    # Inventory
    {"view.inventory", :inventory, "See Inventory (stock, movements)", []},
    {"stock.adjust", :inventory, "Record stock movements and adjustments",
     [{StockOperation, [:record, :adjust]}, {StockMovement, [:create]}]},
    {"stock.reverse", :inventory, "Reverse stock movements", [{StockOperation, [:reverse]}]},
    {"warehouses.manage", :inventory, "Manage warehouses", [{Warehouse, [:create, :update]}]},

    # Manufacturing
    {"view.manufacturing", :manufacturing, "See Manufacturing", []},
    {"work_centers.manage", :manufacturing, "Manage work centers", [{WorkCenter, @crud}]},
    {"boms.manage", :manufacturing, "Manage bills of materials",
     [{BillOfMaterials, @crud}, {BomComponent, @crud}, {BomOperation, @crud}]},
    {"production.manage", :manufacturing, "Plan and run production orders",
     [{ProductionOrder, [:create, :update, :confirm, :record_output, :finish, :cancel]}]},

    # People
    {"view.hr", :hr, "See staff records (employees, departments, org chart)", []},
    {"employees.manage", :hr, "Hire, edit and terminate employees",
     [{HR.Employee, [:create, :update, :terminate, :rehire]}]},
    {"departments.manage", :hr, "Manage departments", [{HR.Department, @crud}]},
    {"leave.setup", :hr, "Set up leave types, policies, balances and holidays",
     [
       {HR.LeaveType, @crud},
       {HR.LeavePolicy, [:create, :update, :assign, :destroy]},
       {HR.LeavePolicyAssignment, [:assign, :destroy]},
       {HR.LeaveBalanceEntry, [:adjust]},
       {HR.Holiday, @crud}
     ]},
    {"leave.request", :hr, "Request leave and claim days for others",
     [{HR.LeaveRequest, [:create, :cancel]}, {HR.LeaveClaim, [:create, :cancel]}]},
    {"leave.approve", :hr, "Approve anyone's leave and leave claims",
     [{HR.LeaveRequest, [:approve, :reject]}, {HR.LeaveClaim, [:approve, :reject]}]},
    {"time.log", :hr, "Log time for others", [{HR.TimeActivity, @crud}]},
    {"time.bill", :hr, "Mark time as billed", [{HR.TimeActivity, [:mark_billed]}]},
    {"checklists.manage", :hr, "Run onboarding and offboarding checklists",
     [
       {HR.ChecklistTemplate, @crud},
       {HR.ChecklistTemplateTask, @crud},
       {HR.EmployeeChecklist, [:start, :cancel]}
     ]},
    {"checklist_tasks.manage", :hr, "Complete checklist tasks for others",
     [{HR.ChecklistTask, [:complete, :reopen]}, {HR.ChecklistAttachment, [:create, :destroy]}]},

    # Expenses
    {"expenses.claim", :expenses, "Create expense claims",
     [{ExpenseClaim, [:create]}, {ExpenseItem, @crud}]},
    {"expenses.manage", :expenses, "Edit, submit and cancel anyone's expense claims",
     [{ExpenseClaim, [:update, :submit, :cancel, :destroy]}]},
    {"expenses.reimburse", :expenses, "Reimburse approved expense claims",
     [{ExpenseClaim, [:reimburse]}]},
    {"expense_categories.manage", :expenses, "Manage expense categories",
     [{ExpenseCategory, @crud}]},

    # Accounting
    {"view.accounting", :accounting, "See Accounting (journal, accounts, statements)", []},
    {"journal.expense", :accounting, "Record expenses paid",
     [{JournalEntry, [:expense]}, {JournalLine, [:create]}]},
    {"journal.post", :accounting, "Post manual journal entries",
     [{JournalEntry, [:create, :post]}]},
    {"journal.reverse", :accounting, "Reverse journal entries", [{JournalEntry, [:reverse]}]},
    {"accounts.manage", :accounting, "Manage the chart of accounts",
     [{Account, [:create, :update, :destroy, :seed, :assign_system_key]}]},
    {"books.setup", :accounting, "Set up the books", [{Ledger, [:setup, :sync_sales]}]},

    # Reports
    {"view.reports", :reports, "See reports", []},
    {"assistant.use", :reports, "Use the AI assistant", []},

    # Company secretarial
    {"view.compliance", :compliance, "See company secretarial records", []},
    {"compliance.manage", :compliance, "Maintain registers, filings and minutes",
     [
       {Compliance.CompanyProfile, [:create, :update]},
       {Compliance.Officer, [:appoint, :update, :cease]},
       {Compliance.ShareClass, @crud},
       {Compliance.Shareholder, [:create, :update]},
       {Compliance.ShareMovement, [:allot, :record, :transfer]},
       {Compliance.BeneficialOwner, [:create, :update, :cease]},
       {Compliance.Charge, [:create, :update, :satisfy]},
       {Compliance.Meeting, [:create, :update]},
       {Compliance.Resolution, @crud},
       {Compliance.ComplianceTask, [:create, :complete, :reopen]},
       {Compliance.StatutoryDocument, [:create, :destroy]}
     ]},

    # Approvals
    {"approvals.setup", :approvals, "Set up approval workflows and groups",
     [
       {ApprovalGroup, @crud},
       {ApprovalGroupMember, [:create, :destroy]},
       {ApprovalWorkflow, @crud},
       {ApprovalStep, @crud}
     ]},

    # Settings and team
    {"company.manage", :settings, "Edit company details and legal entities",
     [{LegalEntity, [:create, :update]}]},
    {"documents.design", :settings, "Upload the logo and design printed documents",
     [{LegalEntity, [:update_document_style, :set_logo, :remove_logo]}]},
    {"branches.manage", :settings, "Manage branches", [{Branch, @crud}]},
    {"team.manage", :settings, "Invite people, remove them and give them roles",
     [{Invitation, [:create, :destroy]}, {Membership, [:set_roles, :destroy]}]},
    {"roles.manage", :settings, "Create and edit roles",
     [{Role, [:create, :update, :reset, :destroy]}]}
  ]

  @all (for {key, section, label, actions} <- @permissions do
          %{key: key, section: section, label: label, actions: actions}
        end)

  @index for %{key: key, actions: actions} <- @all,
             {resource, names} <- actions,
             name <- names,
             into: %{},
             do: {{resource, name}, key}

  @keys Enum.map(@all, & &1.key)
  @views Enum.filter(@keys, &String.starts_with?(&1, "view."))

  def all, do: @all
  def keys, do: @keys
  def views, do: @views

  @doc "Sections in display order: `{key, label, app module or nil}`."
  def sections, do: @sections

  def get(key), do: Enum.find(@all, &(&1.key == key))

  @doc "The permission that covers an action, or nil when roles don't restrict it."
  def for_action(resource, action_name), do: Map.get(@index, {resource, action_name})

  @doc "Every resource with at least one restricted action."
  def resources, do: @index |> Map.keys() |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

  @doc """
  How the resource's policies treat an action, read once from the policies:
  `:admin` (admins only), `:open` (admins, or the member themselves / their
  manager...) or `:member` (any member).
  """
  def level(resource, action_name) do
    key = {__MODULE__, :level, resource, action_name}

    case :persistent_term.get(key, nil) do
      nil ->
        level = compute_level(resource, action_name)
        :persistent_term.put(key, level)
        level

      level ->
        level
    end
  end

  @admin Zippiker.Accounts.Checks.ActorIsAdmin

  # Every applicable policy must pass, so the strictest one decides.
  defp compute_level(resource, action_name) do
    action = Ash.Resource.Info.action(resource, action_name)

    levels =
      for policy <- Ash.Policy.Info.policies(resource),
          applies?(policy.condition, action),
          do: policy_level(policy)

    cond do
      :admin in levels -> :admin
      :open in levels -> :open
      true -> :member
    end
  end

  defp policy_level(policy) do
    authorizers =
      for check <- policy.policies, check.type == :authorize_if, do: check.check_module

    admin? = @admin in authorizers
    others = Enum.reject(authorizers, &(&1 in [@admin, Ash.Policy.Check.Static]))

    cond do
      not admin? -> :member
      others == [] -> :admin
      Zippiker.Accounts.Checks.ActorIsMember in others -> :member
      true -> :open
    end
  end

  defp applies?(conditions, action) do
    Enum.all?(conditions, fn
      {Ash.Policy.Check.Static, opts} -> opts[:result]
      {Ash.Policy.Check.ActionType, opts} -> action.type in List.wrap(opts[:type])
      {Ash.Policy.Check.Action, opts} -> action.name in List.wrap(opts[:action])
      _other -> true
    end)
  end

  @doc """
  Permissions every plain member had before roles existed: all views, and
  every action that isn't admin-only.
  """
  def member_defaults do
    for %{key: key, actions: actions} <- @all,
        Enum.all?(actions, fn {resource, names} ->
          Enum.all?(names, &(level(resource, &1) == :member))
        end),
        do: key
  end

  # Built-in roles

  @sales_rep ~w(view.contacts assistant.use contacts.manage view.crm leads.manage leads.convert deals.manage
                tasks.manage activities.manage view.sales quotes.manage sales_orders.manage
                deliveries.manage invoices.create invoices.issue payments.record view.reports)

  @purchasing ~w(view.contacts assistant.use contacts.manage view.purchasing rfqs.manage rfqs.decide
                 purchase_orders.manage purchase_orders.cancel goods.receive bills.create
                 view.inventory view.reports)

  @hr ~w(view.contacts assistant.use view.hr employees.manage departments.manage leave.setup leave.request
         leave.approve time.log checklists.manage checklist_tasks.manage expenses.claim view.reports)

  @accountant ~w(view.contacts assistant.use contacts.manage view.sales invoices.create invoices.issue
                 invoices.void payments.record payments.delete taxes.manage view.purchasing
                 bills.create bills.approve bills.void bill_payments.record bill_payments.delete
                 expenses.reimburse expense_categories.manage expenses.manage view.accounting journal.expense journal.post
                 journal.reverse accounts.manage books.setup view.reports time.bill)

  @doc "The roles every workspace starts with."
  def default_roles do
    [
      %{
        key: "team_member",
        name: "Team member",
        default?: true,
        description:
          "Everyday access to every module: everything except admin-only actions. " <>
            "Given to new members.",
        permissions: member_defaults()
      },
      %{
        key: "employee",
        name: "Employee",
        default?: false,
        description:
          "Self-service only: their own leave, time, expense claims, tasks and profile.",
        permissions: ~w(view.contacts expenses.claim tasks.manage assistant.use)
      },
      %{
        key: "sales_rep",
        name: "Sales representative",
        default?: false,
        description: "Leads, deals, quotes, orders, invoices and payments.",
        permissions: @sales_rep
      },
      %{
        key: "sales_manager",
        name: "Sales manager",
        default?: false,
        description:
          "Everything a sales rep does, plus products, prices, voids and the pipeline.",
        permissions:
          @sales_rep ++
            ~w(contacts.delete pipeline.manage quotes.decide sales_orders.cancel invoices.void
               payments.delete products.manage taxes.manage portal.manage)
      },
      %{
        key: "purchasing_officer",
        name: "Purchasing officer",
        default?: false,
        description: "Requests for quotation, purchase orders, receiving and supplier bills.",
        permissions: @purchasing
      },
      %{
        key: "storekeeper",
        name: "Storekeeper",
        default?: false,
        description: "Receives and delivers goods, adjusts stock and runs counts.",
        permissions:
          ~w(view.contacts view.inventory stock.adjust stock.reverse warehouses.manage view.purchasing
             goods.receive view.sales deliveries.manage view.reports)
      },
      %{
        key: "accountant",
        name: "Accountant",
        default?: false,
        description: "Books, invoices and bills, payments, reimbursements and reports.",
        permissions: @accountant
      },
      %{
        key: "hr_manager",
        name: "HR manager",
        default?: false,
        description: "Employees, departments, leave set-up and approvals, and checklists.",
        permissions: @hr
      },
      %{
        key: "production_planner",
        name: "Production planner",
        default?: false,
        description: "Work centers, bills of materials and production orders.",
        permissions: ~w(view.manufacturing work_centers.manage boms.manage production.manage
             view.inventory view.reports)
      },
      %{
        key: "company_secretary",
        name: "Company secretary",
        default?: false,
        description: "Statutory registers, filings, meetings and resolutions.",
        permissions: ~w(view.contacts view.compliance compliance.manage)
      },
      %{
        key: "it_support",
        name: "IT support",
        default?: false,
        description:
          "Manages users, invitations, roles, branches and custom fields, without being an admin.",
        permissions:
          ~w(view.contacts team.manage roles.manage branches.manage custom_fields.manage
             company.manage documents.design)
      },
      %{
        key: "viewer",
        name: "Viewer (read only)",
        default?: false,
        description: "Sees every module and report but can't change anything.",
        permissions: @views
      }
    ]
  end

  def default_role(key), do: Enum.find(default_roles(), &(&1.key == key))
end
