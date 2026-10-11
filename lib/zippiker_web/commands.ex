defmodule ZippikerWeb.Commands do
  @moduledoc """
  What the command search (⌘K) can jump to: every page of the modules the
  workspace has, plus actions like "New employee" or "Request leave".
  Admin-only actions are left out for members.
  """

  # {label, path, module (nil = always), admin_only?, extra keywords}
  @actions [
    {"New contact", "/contacts/new", nil, false, "person customer supplier add"},
    {"New company", "/companies/new", nil, false, "organization customer supplier add"},
    {"New lead", "/leads/new", :crm, false, "prospect add"},
    {"New deal", "/deals/new", :crm, false, "opportunity add pipeline"},
    {"New quote", "/quotes/new", :sales, false, "quotation estimate proposal"},
    {"New sales order", "/orders/new", :sales, false, "order sell"},
    {"New invoice", "/invoices/new", :sales, false, "bill customer sell"},
    {"New product", "/products/new", :sales, false, "item service price"},
    {"New request for quotation", "/rfqs/new", :purchasing, false, "rfq supplier price"},
    {"New purchase order", "/purchase-orders/new", :purchasing, false, "po buy supplier"},
    {"New bill", "/bills/new", :purchasing, false, "supplier invoice payable"},
    {"New warehouse", "/inventory/warehouses/new", :inventory, true, "stock location"},
    {"New journal entry", "/accounting/journal/new", :accounting, true, "manual entry posting"},
    {"New account", "/accounting/accounts/new", :accounting, true, "chart of accounts ledger"},
    {"New employee", "/hr/employees/new", :hr, true, "hire staff add person onboard"},
    {"Request leave", "/hr/leave/new", :hr, false, "time off holiday vacation absence"},
    {"Claim leave days", "/hr/leave-claims/new", :hr, false, "overtime time off in lieu"},
    {"Log time", "/hr/time/new", :hr, false, "timesheet hours billable project"},
    {"Start onboarding / offboarding checklist", "/hr/checklists/new", :hr, true,
     "checklist new hire leaver"},
    {"New leave policy", "/hr/leave-policies/new", :hr, true, "entitlement accrual"},
    {"New leave type", "/hr/leave-types/new", :hr, true, "time off kind"},
    {"New public holiday", "/hr/holidays/new", :hr, true, "holiday calendar"},
    {"New department", "/hr/departments/new", :hr, true, "team unit"},
    {"New expense claim", "/expenses/new", :expenses, false, "reimbursement receipt spend"},
    {"New production order", "/manufacturing/orders/new", :manufacturing, false,
     "make produce mo"},
    {"New bill of materials", "/manufacturing/boms/new", :manufacturing, true,
     "bom recipe components"},
    {"Appoint a director", "/compliance/officers", :compliance, true,
     "company secretary board officer"},
    {"Filing calendar", "/compliance/filings", :compliance, false,
     "annual return registrar brs ecitizen"},
    {"New approval workflow", "/approvals/workflows/new", nil, true, "approver maker checker"},
    {"New branch", "/settings/branches/new", nil, true, "location office shop"},
    {"New tax rate", "/settings/taxes/new", :sales, true, "vat tax"},
    {"My workspace", "/me", :hr, false, "self service profile balances"},
    {"Help center", "/help", nil, false, "docs how to support"}
  ]

  @doc "Commands for the current user and workspace: `%{label, group, path, keywords}`."
  def list(organization, role) do
    admin? = role in [:owner, :admin]

    actions =
      for {label, path, module, admin_only?, keywords} <- @actions,
          is_nil(module) or ZippikerWeb.Modules.enabled?(organization, module),
          admin? or not admin_only? do
        %{label: label, group: "Actions", path: path, keywords: keywords}
      end

    pages =
      for section <- ZippikerWeb.Layouts.sections(organization),
          {_key, label, path, _module} <- section.pages do
        %{
          label: if(label == section.label, do: label, else: "#{section.label} › #{label}"),
          group: "Pages",
          path: path,
          keywords: section.label
        }
      end

    reports =
      for report <- Zippiker.Reporting.Catalog.available(organization) do
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
