defmodule ZippikerWeb.Commands do
  @moduledoc """
  What the command search (⌘K) can jump to: every page of the modules the
  workspace has, plus actions like "New employee" or "Request leave".
  Admin-only actions are left out for members.
  """

  # {label, path, module (nil = always), permission (nil = anyone), extra keywords}
  @actions [
    {"New contact", "/contacts/new", nil, "contacts.manage", "person customer supplier add"},
    {"New company", "/companies/new", nil, "contacts.manage",
     "organization customer supplier add"},
    {"New customer", "/customers/new", :sales, "contacts.manage", "client buyer account add"},
    {"New supplier", "/suppliers/new", :purchasing, "contacts.manage", "vendor seller add"},
    {"New lead", "/leads/new", :crm, "leads.manage", "prospect add"},
    {"New deal", "/deals/new", :crm, "deals.manage", "opportunity add pipeline"},
    {"New quote", "/quotes/new", :sales, "quotes.manage", "quotation estimate proposal"},
    {"New sales order", "/orders/new", :sales, "sales_orders.manage", "order sell"},
    {"New invoice", "/invoices/new", :sales, "invoices.create", "bill customer sell"},
    {"New product", "/products/new", :sales, "products.manage", "item service price"},
    {"New request for quotation", "/rfqs/new", :purchasing, "rfqs.manage", "rfq supplier price"},
    {"New purchase order", "/purchase-orders/new", :purchasing, "purchase_orders.manage",
     "po buy supplier"},
    {"New bill", "/bills/new", :purchasing, "bills.create", "supplier invoice payable"},
    {"New warehouse", "/inventory/warehouses/new", :inventory, "warehouses.manage",
     "stock location"},
    {"New journal entry", "/accounting/journal/new", :accounting, "journal.post",
     "manual entry posting"},
    {"New account", "/accounting/accounts/new", :accounting, "accounts.manage",
     "chart of accounts ledger"},
    {"New employee", "/hr/employees/new", :hr, "employees.manage",
     "hire staff add person onboard"},
    {"Request leave", "/hr/leave/new", :hr, nil, "time off holiday vacation absence"},
    {"Claim leave days", "/hr/leave-claims/new", :hr, nil, "overtime time off in lieu"},
    {"Log time", "/hr/time/new", :hr, nil, "timesheet hours billable project"},
    {"Start onboarding / offboarding checklist", "/hr/checklists/new", :hr, "checklists.manage",
     "checklist new hire leaver"},
    {"New leave policy", "/hr/leave-policies/new", :hr, "leave.setup", "entitlement accrual"},
    {"New leave type", "/hr/leave-types/new", :hr, "leave.setup", "time off kind"},
    {"New public holiday", "/hr/holidays/new", :hr, "leave.setup", "holiday calendar"},
    {"New department", "/hr/departments/new", :hr, "departments.manage", "team unit"},
    {"New expense claim", "/expenses/new", :expenses, "expenses.claim",
     "reimbursement receipt spend"},
    {"New production order", "/manufacturing/orders/new", :manufacturing, "production.manage",
     "make produce mo"},
    {"New bill of materials", "/manufacturing/boms/new", :manufacturing, "boms.manage",
     "bom recipe components"},
    {"Appoint a director", "/compliance/officers", :compliance, "compliance.manage",
     "company secretary board officer"},
    {"Filing calendar", "/compliance/filings", :compliance, "view.compliance",
     "annual return registrar brs ecitizen"},
    {"New approval workflow", "/approvals/workflows/new", nil, "approvals.setup",
     "approver maker checker"},
    {"New branch", "/settings/branches/new", nil, "branches.manage", "location office shop"},
    {"New tax rate", "/settings/taxes/new", :sales, "taxes.manage", "vat tax"},
    {"My workspace", "/me", :hr, nil, "self service profile balances"},
    {"Ask the assistant", "/assistant", nil, "assistant.use", "ai claude chat question help"},
    {"Help center", "/help", nil, nil, "docs how to support"}
  ]

  @doc "Commands for the current user and workspace: `%{label, group, path, keywords}`."
  def list(organization, _role, permissions \\ :all) do
    actions =
      for {label, path, module, permission, keywords} <- @actions,
          is_nil(module) or ZippikerWeb.Modules.enabled?(organization, module),
          is_nil(permission) or ZippikerWeb.Access.can?(permissions, permission) do
        %{label: label, group: "Actions", path: path, keywords: keywords}
      end

    pages =
      for section <- ZippikerWeb.Layouts.sections(organization, permissions),
          {_key, label, path, _module} <- section.pages do
        %{
          label: if(label == section.label, do: label, else: "#{section.label} › #{label}"),
          group: "Pages",
          path: path,
          keywords: section.label
        }
      end

    reports =
      for report <- ZippikerWeb.Access.reports(organization, permissions) do
        %{
          label: report.title,
          group: "Reports",
          path: "/reports/#{report.key}",
          keywords: "report #{report.description}"
        }
      end

    actions ++ Enum.uniq_by(pages, & &1.path) ++ reports
  end
end
