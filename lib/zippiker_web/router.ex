defmodule ZippikerWeb.Router do
  use ZippikerWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZippikerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", ZippikerWeb do
    pipe_through :browser

    get "/invitations/:token", WorkspaceController, :invitation
    post "/workspaces/:id/switch", WorkspaceController, :switch
    get "/hr/leave/:id/attachment", LeaveAttachmentController, :show

    post "/workspaces/:organization_id/impersonate/:user_id",
         WorkspaceController,
         :impersonate

    post "/platform/users/:id/impersonate", PlatformController, :impersonate
    delete "/platform/impersonation", PlatformController, :stop_impersonating
    post "/platform/teams/:id/access", PlatformController, :access
    delete "/platform/access", PlatformController, :leave

    ash_authentication_live_session :platform,
      on_mount: {ZippikerWeb.LiveUserAuth, :live_super_admin} do
      live "/platform", Platform.OverviewLive
      live "/platform/teams", Platform.TeamsLive
      live "/platform/teams/:id", Platform.TeamLive, :show
      live "/platform/teams/:id/subscription", Platform.TeamLive, :subscription
      live "/platform/users", Platform.UsersLive
      live "/platform/plans", Platform.PlansLive, :index
      live "/platform/plans/new", Platform.PlansLive, :new
      live "/platform/plans/:id/edit", Platform.PlansLive, :edit
      live "/platform/billing", Platform.BillingLive
    end

    ash_authentication_live_session :print,
      on_mount: {ZippikerWeb.LiveUserAuth, :live_workspace} do
      live "/quotes/:id/print", DocumentLive.Print, :quote
      live "/invoices/:id/print", DocumentLive.Print, :invoice
      live "/orders/:id/print", DocumentLive.Print, :sales_order
      live "/purchase-orders/:id/print", DocumentLive.Print, :purchase_order
      live "/rfqs/:id/print", DocumentLive.Print, :rfq
      live "/inventory/operations/:id/print", InventoryLive.OperationPrint, :show
      live "/goods-receipts/print", NotesPrintLive, :goods_receipts
      live "/deliveries/print", NotesPrintLive, :deliveries
      live "/goods-receipts/:id/print", GoodsReceiptLive.Show, :print
      live "/deliveries/:id/print", DeliveryLive.Show, :print
    end

    ash_authentication_live_session :onboarding,
      on_mount: {ZippikerWeb.LiveUserAuth, :live_user_required} do
      live "/onboarding", OnboardingLive
      live "/invitations/:token/accept", InvitationLive
    end

    ash_authentication_live_session :workspace,
      on_mount: {ZippikerWeb.LiveUserAuth, :live_workspace} do
      live "/", DashboardLive

      live "/leads", LeadLive.Index, :index
      live "/leads/new", LeadLive.Index, :new
      live "/leads/:id", LeadLive.Show, :show
      live "/leads/:id/edit", LeadLive.Show, :edit
      live "/leads/:id/convert", LeadLive.Show, :convert

      live "/contacts", PartyLive.Index, :contacts
      live "/contacts/new", PartyLive.Index, :new_contact
      live "/contacts/:id", PartyLive.Show, :show
      live "/contacts/:id/edit", PartyLive.Show, :edit

      live "/companies", PartyLive.Index, :companies
      live "/companies/new", PartyLive.Index, :new_company
      live "/companies/:id", PartyLive.Show, :show
      live "/companies/:id/edit", PartyLive.Show, :edit

      live "/deals", DealLive.Board, :index
      live "/deals/new", DealLive.Board, :new
      live "/deals/:id", DealLive.Show, :show
      live "/deals/:id/edit", DealLive.Show, :edit

      live "/tasks", TaskLive.Index, :index

      live "/settings/custom-fields", Settings.CustomFieldsLive, :index
      live "/settings/custom-fields/new", Settings.CustomFieldsLive, :new
      live "/settings/custom-fields/:id/edit", Settings.CustomFieldsLive, :edit
      live "/settings/pipeline", Settings.PipelineLive, :index
      live "/settings/workspace", Settings.WorkspaceLive, :index
      live "/settings/company", Settings.CompanyLive, :index
      live "/settings/company/new", Settings.CompanyLive, :new
      live "/settings/company/:id", Settings.CompanyLive, :edit
      live "/settings/branches", Settings.BranchesLive, :index
      live "/settings/branches/new", Settings.BranchesLive, :new
      live "/settings/branches/:id/edit", Settings.BranchesLive, :edit
      live "/settings/taxes", Settings.TaxesLive, :index
      live "/settings/taxes/new", Settings.TaxesLive, :new
      live "/settings/taxes/:id/edit", Settings.TaxesLive, :edit

      live "/products", ProductLive.Index, :index
      live "/products/new", ProductLive.Index, :new
      live "/products/:id/edit", ProductLive.Index, :edit

      live "/quotes", QuoteLive.Index, :index
      live "/quotes/new", DocumentLive.Form, :new_quote
      live "/quotes/:id", QuoteLive.Show, :show
      live "/quotes/:id/edit", DocumentLive.Form, :edit_quote

      live "/orders", SalesOrderLive.Index, :index
      live "/orders/new", DocumentLive.Form, :new_sales_order
      live "/orders/:id", SalesOrderLive.Show, :show
      live "/orders/:id/edit", DocumentLive.Form, :edit_sales_order
      live "/orders/:id/deliver", SalesOrderLive.Show, :deliver

      live "/rfqs", RfqLive.Index, :index
      live "/rfqs/new", DocumentLive.Form, :new_rfq
      live "/rfqs/:id", RfqLive.Show, :show
      live "/rfqs/:id/edit", DocumentLive.Form, :edit_rfq

      live "/purchase-orders", PurchaseOrderLive.Index, :index
      live "/purchase-orders/new", DocumentLive.Form, :new_purchase_order
      live "/purchase-orders/:id", PurchaseOrderLive.Show, :show
      live "/purchase-orders/:id/edit", DocumentLive.Form, :edit_purchase_order
      live "/purchase-orders/:id/receive", PurchaseOrderLive.Show, :receive

      live "/goods-receipts", GoodsReceiptLive.Index, :index
      live "/goods-receipts/:id", GoodsReceiptLive.Show, :show

      live "/deliveries", DeliveryLive.Index, :index
      live "/deliveries/:id", DeliveryLive.Show, :show
      live "/deliveries/:id/confirm", DeliveryLive.Show, :confirm

      live "/bills", BillLive.Index, :index
      live "/bills/new", DocumentLive.Form, :new_bill
      live "/bills/:id", BillLive.Show, :show
      live "/bills/:id/edit", DocumentLive.Form, :edit_bill
      live "/bills/:id/payment", BillLive.Show, :payment

      live "/inventory", InventoryLive.Stock, :index
      live "/inventory/adjust", InventoryLive.Stock, :adjust
      live "/inventory/products/:id", InventoryLive.Product, :show
      live "/inventory/operations", InventoryLive.Operations, :index
      live "/inventory/operations/:id", InventoryLive.Operation, :show
      live "/inventory/warehouses", InventoryLive.Warehouses, :index
      live "/inventory/warehouses/new", InventoryLive.Warehouses, :new
      live "/inventory/warehouses/:id/edit", InventoryLive.Warehouses, :edit

      live "/invoices", InvoiceLive.Index, :index
      live "/invoices/new", DocumentLive.Form, :new_invoice
      live "/invoices/:id", InvoiceLive.Show, :show
      live "/invoices/:id/edit", DocumentLive.Form, :edit_invoice
      live "/invoices/:id/payment", InvoiceLive.Show, :payment

      live "/accounting", AccountingLive.Overview, :index
      live "/accounting/expense", AccountingLive.Overview, :expense
      live "/accounting/accounts", AccountingLive.Accounts, :index
      live "/accounting/accounts/new", AccountingLive.Accounts, :new
      live "/accounting/accounts/:id/edit", AccountingLive.Accounts, :edit
      live "/accounting/accounts/:id", AccountingLive.Ledger, :show
      live "/accounting/journal", AccountingLive.Journal, :index
      live "/accounting/journal/new", AccountingLive.JournalForm, :new
      live "/accounting/journal/:id", AccountingLive.Entry, :show
      live "/accounting/reports", AccountingLive.Reports, :index

      live "/settings/billing", Settings.BillingLive, :index

      live "/hr/employees", EmployeeLive.Index, :index
      live "/hr/employees/new", EmployeeLive.Form, :new
      live "/hr/employees/:id", EmployeeLive.Show, :show
      live "/hr/employees/:id/edit", EmployeeLive.Form, :edit
      live "/hr/employees/:id/terminate", EmployeeLive.Show, :terminate
      live "/hr/employees/:id/adjust-leave", EmployeeLive.Show, :adjust_leave
      live "/hr/leave", LeaveLive.Index, :index
      live "/hr/leave/new", LeaveLive.Index, :new
      live "/hr/org-chart", HRLive.OrgChart, :index
      live "/hr/departments", HRLive.Departments, :index
      live "/hr/departments/new", HRLive.Departments, :new
      live "/hr/departments/:id/edit", HRLive.Departments, :edit
      live "/hr/leave-policies", HRLive.LeavePolicies, :index
      live "/hr/leave-policies/new", HRLive.LeavePolicies, :new
      live "/hr/leave-policies/:id/edit", HRLive.LeavePolicies, :edit
      live "/hr/leave-policies/:id/assign", HRLive.LeavePolicies, :assign
      live "/hr/leave-claims", LeaveLive.Claims, :index
      live "/hr/leave-claims/new", LeaveLive.Claims, :new
      live "/hr/holidays", HRLive.Holidays, :index
      live "/hr/holidays/new", HRLive.Holidays, :new
      live "/hr/holidays/:id/edit", HRLive.Holidays, :edit
      live "/hr/leave-types", HRLive.LeaveTypes, :index
      live "/hr/leave-types/new", HRLive.LeaveTypes, :new
      live "/hr/leave-types/:id/edit", HRLive.LeaveTypes, :edit

      live "/manufacturing/orders", ProductionLive.Index, :index
      live "/manufacturing/orders/new", ProductionLive.Index, :new
      live "/manufacturing/orders/:id", ProductionLive.Show, :show
      live "/manufacturing/orders/:id/edit", ProductionLive.Show, :edit
      live "/manufacturing/orders/:id/produce", ProductionLive.Show, :produce
      live "/manufacturing/orders/:id/print", ProductionLive.JobCard, :print
      live "/manufacturing/boms", BomLive.Index, :index
      live "/manufacturing/boms/new", BomLive.Form, :new
      live "/manufacturing/boms/:id/edit", BomLive.Form, :edit
      live "/manufacturing/work-centers", ProductionLive.WorkCenters, :index
      live "/manufacturing/work-centers/new", ProductionLive.WorkCenters, :new
      live "/manufacturing/work-centers/:id/edit", ProductionLive.WorkCenters, :edit

      live "/approvals", WorkflowLive.Inbox, :index
      live "/approvals/history", WorkflowLive.History, :index
      live "/approvals/changes", WorkflowLive.ChangeRequests, :index
      live "/approvals/changes/:id", WorkflowLive.ChangeRequests, :show
      live "/approvals/workflows", WorkflowLive.Workflows, :index
      live "/approvals/workflows/new", WorkflowLive.Workflows, :new
      live "/approvals/workflows/:id/edit", WorkflowLive.Workflows, :edit
      live "/approvals/groups", WorkflowLive.Groups, :index
      live "/approvals/groups/new", WorkflowLive.Groups, :new
      live "/approvals/groups/:id/edit", WorkflowLive.Groups, :edit

      live "/expenses", ExpenseLive.Index, :mine
      live "/expenses/all", ExpenseLive.Index, :all
      live "/expenses/new", ExpenseLive.Form, :new
      live "/expenses/categories", ExpenseLive.Categories, :index
      live "/expenses/categories/new", ExpenseLive.Categories, :new
      live "/expenses/categories/:id/edit", ExpenseLive.Categories, :edit
      live "/expenses/:id", ExpenseLive.Show, :show
      live "/expenses/:id/edit", ExpenseLive.Form, :edit
      live "/expenses/:id/reimburse", ExpenseLive.Show, :reimburse

      live "/help", HelpLive, :index
      live "/help/:slug", HelpLive, :show
    end
  end

  scope "/", ZippikerWeb do
    pipe_through :browser

    auth_routes AuthController, Zippiker.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      overrides: [ZippikerWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{ZippikerWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    ZippikerWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  ZippikerWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Zippiker.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [ZippikerWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Zippiker.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [ZippikerWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZippikerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:zippiker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ZippikerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:zippiker, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
