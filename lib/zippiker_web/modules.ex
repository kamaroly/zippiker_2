defmodule ZippikerWeb.Modules do
  @moduledoc """
  Business modules a workspace can have switched on (`Organization.enabled_modules`).
  Contacts, companies, the dashboard and settings are always available.
  Disabling a module hides it and blocks its pages; its data is kept.
  """

  @modules [
    %{
      key: :crm,
      name: "CRM",
      icon: "hero-funnel",
      description: "Leads, deal pipeline, tasks and activities."
    },
    %{
      key: :sales,
      name: "Sales",
      icon: "hero-document-text",
      description: "Products, taxes, quotes, invoices and payments."
    },
    %{
      key: :purchasing,
      name: "Purchasing",
      icon: "hero-shopping-cart",
      description: "Purchase orders, receiving goods, supplier bills and payments."
    },
    %{
      key: :inventory,
      name: "Inventory",
      icon: "hero-archive-box",
      description: "Warehouses, stock levels, movements and adjustments."
    },
    %{
      key: :hr,
      name: "HR",
      icon: "hero-user-group",
      description: "Employees, departments, org chart and leave."
    },
    %{
      key: :expenses,
      name: "Expenses",
      icon: "hero-receipt-percent",
      description: "Expense claims, approval workflows and reimbursements."
    },
    %{
      key: :manufacturing,
      name: "Manufacturing",
      icon: "hero-wrench-screwdriver",
      description: "Bills of materials, work centers and production orders."
    },
    %{
      key: :compliance,
      name: "Company secretarial",
      icon: "hero-building-library",
      description: "Statutory registers, meetings and filings (Kenya Companies Act, 2015)."
    },
    %{
      key: :accounting,
      name: "Accounting",
      icon: "hero-calculator",
      description: "Chart of accounts, journal, expenses and financial reports."
    }
  ]

  @views %{
    crm: [
      ZippikerWeb.LeadLive.Index,
      ZippikerWeb.LeadLive.Show,
      ZippikerWeb.DealLive.Board,
      ZippikerWeb.DealLive.Show,
      ZippikerWeb.TaskLive.Index,
      ZippikerWeb.Settings.PipelineLive
    ],
    sales: [
      ZippikerWeb.QuoteLive.Index,
      ZippikerWeb.QuoteLive.Show,
      ZippikerWeb.InvoiceLive.Index,
      ZippikerWeb.InvoiceLive.Show,
      ZippikerWeb.SalesOrderLive.Index,
      ZippikerWeb.SalesOrderLive.Show,
      ZippikerWeb.DeliveryLive.Index,
      ZippikerWeb.DeliveryLive.Show,
      ZippikerWeb.ProductLive.Index,
      ZippikerWeb.Settings.TaxesLive
    ],
    purchasing: [
      ZippikerWeb.PurchaseOrderLive.Index,
      ZippikerWeb.PurchaseOrderLive.Show,
      ZippikerWeb.RfqLive.Index,
      ZippikerWeb.RfqLive.Show,
      ZippikerWeb.GoodsReceiptLive.Index,
      ZippikerWeb.GoodsReceiptLive.Show,
      ZippikerWeb.BillLive.Index,
      ZippikerWeb.BillLive.Show
    ],
    inventory: [
      ZippikerWeb.InventoryLive.Stock,
      ZippikerWeb.InventoryLive.Product,
      ZippikerWeb.InventoryLive.Operations,
      ZippikerWeb.InventoryLive.Operation,
      ZippikerWeb.InventoryLive.OperationPrint,
      ZippikerWeb.InventoryLive.Warehouses
    ],
    hr: [
      ZippikerWeb.EmployeeLive.Index,
      ZippikerWeb.EmployeeLive.Show,
      ZippikerWeb.EmployeeLive.Form,
      ZippikerWeb.LeaveLive.Index,
      ZippikerWeb.HRLive.OrgChart,
      ZippikerWeb.HRLive.Departments,
      ZippikerWeb.HRLive.LeaveTypes,
      ZippikerWeb.HRLive.LeavePolicies,
      ZippikerWeb.HRLive.Holidays,
      ZippikerWeb.LeaveLive.Claims,
      ZippikerWeb.MeLive.Overview,
      ZippikerWeb.MeLive.Tasks,
      ZippikerWeb.MeLive.Profile,
      ZippikerWeb.ChecklistLive.Index,
      ZippikerWeb.ChecklistLive.Show,
      ZippikerWeb.ChecklistLive.Templates
    ],
    expenses: [
      ZippikerWeb.ExpenseLive.Index,
      ZippikerWeb.ExpenseLive.Show,
      ZippikerWeb.ExpenseLive.Form,
      ZippikerWeb.ExpenseLive.Categories
    ],
    manufacturing: [
      ZippikerWeb.ProductionLive.Index,
      ZippikerWeb.ProductionLive.Show,
      ZippikerWeb.ProductionLive.JobCard,
      ZippikerWeb.ProductionLive.WorkCenters,
      ZippikerWeb.BomLive.Index,
      ZippikerWeb.BomLive.Form
    ],
    compliance: [
      ZippikerWeb.ComplianceLive.Overview,
      ZippikerWeb.ComplianceLive.Filings,
      ZippikerWeb.ComplianceLive.Officers,
      ZippikerWeb.ComplianceLive.Members,
      ZippikerWeb.ComplianceLive.Owners,
      ZippikerWeb.ComplianceLive.Charges,
      ZippikerWeb.ComplianceLive.Meetings,
      ZippikerWeb.ComplianceLive.Documents,
      ZippikerWeb.ComplianceLive.Print
    ],
    accounting: [
      ZippikerWeb.AccountingLive.Overview,
      ZippikerWeb.AccountingLive.Accounts,
      ZippikerWeb.AccountingLive.Ledger,
      ZippikerWeb.AccountingLive.Journal,
      ZippikerWeb.AccountingLive.JournalForm,
      ZippikerWeb.AccountingLive.Entry,
      ZippikerWeb.AccountingLive.Reports
    ]
  }

  def all, do: @modules

  def name(key), do: Enum.find_value(@modules, &(&1.key == key && &1.name))

  def enabled?(%{enabled_modules: modules}, key) when is_list(modules), do: key in modules
  def enabled?(_organization, _key), do: false

  # Shared pages belong to the module of the document they're showing.
  @actions %{
    new_quote: :sales,
    edit_quote: :sales,
    new_sales_order: :sales,
    edit_sales_order: :sales,
    new_invoice: :sales,
    edit_invoice: :sales,
    quote: :sales,
    sales_order: :sales,
    invoice: :sales,
    new_purchase_order: :purchasing,
    edit_purchase_order: :purchasing,
    purchase_order: :purchasing,
    new_bill: :purchasing,
    goods_receipts: :purchasing,
    deliveries: :sales,
    new_rfq: :purchasing,
    edit_rfq: :purchasing,
    rfq: :purchasing,
    edit_bill: :purchasing
  }

  @doc "The module a LiveView (and live action) belongs to, or nil for core pages."
  def for_view(view, action \\ nil)

  def for_view(view, action)
      when view in [
             ZippikerWeb.DocumentLive.Form,
             ZippikerWeb.DocumentLive.Print,
             ZippikerWeb.NotesPrintLive
           ],
      do: Map.get(@actions, action)

  def for_view(view, _action) do
    Enum.find_value(@views, fn {key, views} -> view in views && key end)
  end
end
