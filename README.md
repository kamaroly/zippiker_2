# Zippiker

A CRM built with Ash + Phoenix LiveView, designed as the first module of an ERP.

## Run it

```bash
mix setup                        # deps, database (zippiker_crm_dev), assets
mix run priv/repo/seeds.exs      # demo workspace: demo@zippiker.com / password123
                                 # platform admin:  admin@zippiker.com / password123
mix phx.server                   # http://localhost:4000 (PORT=4100 mix phx.server to change)
```

Database credentials come from `PGUSER` / `PGPASSWORD` (see `config/dev.exs`).
Before committing, run `mix precommit`.

## Architecture

A modular monolith: each business area is its own Ash domain, all tenant-scoped by organization.

| Domain | Purpose |
|---|---|
| `Zippiker.Accounts` | Users, organizations (the Ash tenant), memberships and roles, invitations, legal entities, gap-free document numbering, policy checks |
| `Zippiker.Extensibility` | Tenant-defined custom fields for any resource |
| `Zippiker.Parties` | People and organizations shared by every module (contacts, companies, later customers, suppliers and employees) |
| `Zippiker.Catalog` | Products/services and tax rates |
| `Zippiker.Crm` | Leads, pipelines and stages, deals, activities, tasks, dashboard |
| `Zippiker.Sales` | Quotes, sales orders, invoices, payments, sales reports. Lines priced by `Zippiker.Sales.Pricing` |
| `Zippiker.Purchasing` | Purchase orders (receiving), supplier bills and bill payments, payables report |
| `Zippiker.HR` | Departments, employees (Parties people + job, reporting line, pay with field policies), leave types, leave requests with manager approval, org chart |
| `Zippiker.Workflow` | Configurable approvals for any document: groups, workflows (ordered steps: manager / user / group / admins), requests with step snapshots |
| `Zippiker.Expenses` | Expense categories, employee expense claims (approval workflow, posting, reimbursement) |
| `Zippiker.Manufacturing` | Work centers, bills of materials (components + operations), production orders with partial output |
| `Zippiker.Inventory` | Warehouses, stock operations (receipts, deliveries, adjustments) made of movements, weighted average cost |
| `Zippiker.Accounting` | Chart of accounts, immutable double-entry journal, posting rules (`Ledger`), financial statements (`Reports`) |
| `Zippiker.Platform` | The SaaS layer: plans, one subscription per workspace, platform invoices, audit log, super admin overview (global, not tenant-scoped) |

Conventions (see `AGENTS.md`):

- LiveViews and LiveComponents keep their markup in colocated `.html.heex` templates.
- Each resource is split into fragments in a folder named after it (`deal/attributes.ex`, `deal/actions.ex`...).
- Changes, validations and preparations live in their own subfolders.
- Domain-level logic is exposed as generic actions (e.g. `Crm.dashboard_summary`, `Crm.seed_crm_defaults`), not ad-hoc functions.
- Modules depend on `Parties` and `Accounts`, never the other way round. The only exception is
  `Organization.create` starting a `Platform` subscription.
- Other modules post to the books through `Zippiker.Accounting` generic actions (e.g.
  `Sales.Changes.PostToLedger`), inside their own transaction.

### Custom fields

Add the extension to a resource and it becomes extensible:

```elixir
use Ash.Resource, extensions: [Zippiker.Extensibility.CustomFields]

custom_fields do
  entity :deal          # or `entity_from :kind`
end
```

This adds a `custom_fields` JSONB attribute and a change that casts and validates values against
the organization's `CustomFieldDefinition`s. Register new entities in `Zippiker.Extensibility.Entity`.
Admins manage fields under **Settings → Custom fields**.

### Multi-tenancy and authorization

Each team has its own Postgres schema (Ash `:context` multitenancy), named after the team's
domain: `acme.com` → `acme_com`, or `team_1`, `team_2`… when no domain is given at sign-up
(`Organization.domain` / `schema_name`, see `Zippiker.Accounts.Tenant`). Users, organizations,
memberships, invitations, auth tokens, Oban jobs and the platform's plans and billing stay in
`public`. Business resources have no `organization_id`; the organization struct is the tenant
(`Ash.ToTenant` gives the schema) and policies use the `ActorIsMember` / `ActorIsAdmin` checks.
LiveViews pass `ash_opts(socket)` (`actor` + `tenant`) to every call.

- Tenant tables come from `priv/repo/tenant_migrations` (`mix ash.codegen` writes them). A new
  team's schema is built when the team is created (`Organization.Changes.CreateTenant`).
- `mix ecto.migrate` also runs `mix zippiker.tenants.migrate`: every team schema gets pending
  tenant migrations, and data from the old single-schema layout is moved in once, then the old
  public tables are dropped (`Zippiker.Accounts.Tenant.Migrator`; call `run/0` from a release).
- Tests check out pre-built schemas from `Zippiker.TenantPool` (built once into the test
  database) instead of building one per team.

### Sales flow

Deal → **Quote** (`QUO-2026-0001`, numbered on creation) → accept (wins the deal) →
**Invoice** draft → issue (gets `INV-2026-0001`, due date from payment terms) →
**Payments** until paid. Issued invoices are never edited; void and re-issue instead.
Print / Save as PDF from any document (`/quotes/:id/print`, `/invoices/:id/print`).

### Accounting

Issuing an invoice posts *DR receivable / CR revenue + tax payable*; a payment posts
*DR cash, bank or mobile money / CR receivable*; voiding or deleting reverses the entry.
Postings are idempotent per source document (`journal_entries.source` + `source_id`), and
`Accounting.sync_sales` backfills history ("Set up accounting" in the UI). Entries are
never updated; `reverse` posts the mirror image. Reports are computed with per-account
aggregates over `journal_lines.date`.

### Purchasing & inventory

PO → **receive** (GRN; stock in at net unit price, DR inventory / CR goods received not billed) →
**bill** from the PO (lines keep `received_unit_cost`; approving clears GRNI, price variance to cost
of sales, input tax, CR payable) → **bill payments**. Bills without a PO bring tracked goods in on
approval. Sales: quote → **sales order** → **deliver** (DO; stock out at average cost, DR cost of
sales / CR inventory) → invoice; an invoice not delivered by its order ships on issue. Voids reverse
both stock and books. Stock operations are immutable; `reverse` posts the opposite movements.
Document lines share `Sales.DocumentLine.Attributes` (+ `Actions`); purchase lines add their own
fields in extra fragments.

Paperwork: receiving writes a `Purchasing.GoodsReceipt` (GRN, every line) and shipping writes a
`Sales.Delivery` (delivery note, goods lines; shipped → delivered with proof of delivery); tracked
products additionally get an `Inventory.StockOperation` (`MV-…`) linked from the note. Purchase orders
receive and sales orders deliver in parts (`received_quantity` / `delivered_quantity` per line).
RFQ (`Purchasing.Rfq`) → purchase order mirrors quote → sales order. Every document form accepts
`?copy=<id>` (Duplicate) and `?customer_id=` / `?supplier_id=` (the party page's New menu).

### HR

Employees are `Parties` people (created from the hire form) with an `EMP-0001` number (non-yearly
sequence). `user_id` links a login: the actor's record (`HR.my_employee_record`) is used for their own
leave. Pending requests go through the workflow engine (`:leave_request`, amount = days); with no
leave workflow the default step is the manager, or the admins when there is none
(`:manager_or_admins`). `approve_leave` / `reject_leave` decide the current step, the workflow's
outcome is applied by `HR.apply_leave_approval`, and cancelling or an overdue auto-decision
withdraws the approval. Requests from before workflows are decided directly.

Leave policies are per leave type (`LeavePolicy`): category `:fixed` (days per year + carry-over),
`:accrual` (credited per week/month/quarter/year up to a cap), `:manual` (adjustments and claims
only) or `:unlimited`, plus request rules (attachment required, count weekends and holidays,
backdating, claimable, review threshold with an automatic approve/reject). Employees get at most one
policy per type (`LeavePolicyAssignment`); otherwise the type's default policy applies, else the
type's `allowance_days`. `HR.Entitlement` computes balances from the policy, `LeaveBalanceEntry`
rows (accruals, admin adjustments, approved `LeaveClaim`s) and pending/approved requests. Days are
Mon–Fri minus `Holiday`s (`HR.WorkingDays`) unless the policy counts every day.

Onboarding/offboarding: `ChecklistTemplate` (+ `ChecklistTemplateTask`: assignee role hr / manager /
employee / user, `due_in_days`, `requires_attachment?`) → `EmployeeChecklist` with `ChecklistTask`s
(assignee resolved at start, due date from `base_date`) and `ChecklistAttachment`s. The default
template of each kind starts on `Employee.create` / `terminate` (`StartDefaultChecklist`); a tenant
migration seeds standard templates. Completing a task needs an attachment when required; the
checklist completes when all tasks are done.

Background jobs use Oban (`config :zippiker, Oban`): `HR.Workers.RunAccruals` daily and
`HR.Workers.ReviewOverdueLeave` hourly, for every workspace with HR on. Both call generic actions
on `HR.Automation` (`run_leave_accruals`, `review_overdue_leave`), which are idempotent. Leave
attachments are stored under `:uploads_dir` (`ZippikerWeb.Uploads`) and served by
`LeaveAttachmentController` after an access check. Salary and personal fields
are protected by field policies (admins and the employee only).

### Approvals and expenses

`Zippiker.Workflow` is document-agnostic. `ApprovalRequest.start` picks the active workflow for the
`document_type` with the highest `min_amount` not above the document amount (no workflow = any
workspace admin) and snapshots its steps. Steps go waiting → pending → approved / rejected, or
skipped when nobody but the initiator could approve (`Workflow.Approvers`). `decide` checks the
actor is an approver of the pending step (`ActorCanDecide`); `approval_inbox` lists what the actor
can decide. When a request finishes, `Workflow.Callbacks.finished/2` tells the document
(`Expenses.apply_approval`). To add a new approvable document, register it in
`Workflow.DocumentTypes`, start the approval from its submit action, add a `Callbacks` clause
and a `WorkflowComponents.document_path/1` clause. The Approvals menu (inbox across modules,
history, workflows, groups) lives at `/approvals` (`ZippikerWeb.WorkflowLive.*`).

Expense claims (`EXP-…`) go draft → submitted → approved → reimbursed (or rejected → edit and
resubmit, or cancelled). Approval posts DR category expense accounts / CR "Employee reimbursements"
(system key `:reimbursements`); reimbursing posts DR reimbursements / CR cash, bank or mobile money.

### Branches

`Accounts.Branch` (tenant) with one default (`Accounts.default_branch`, created as "Head office"/HQ
when missing; a tenant migration backfilled existing records). Quotes, sales orders, invoices,
RFQs, purchase orders, bills, expense claims, production orders, employees, warehouses and journal
entries have `branch_id`, defaulted by `Accounts.Changes.SetBranch` (from the source document when
there is one). Postings copy the document's branch (stock operations: the warehouse's). The
financial reports take an optional `branch_id`. `Organization.multi_branch?` (Settings → Branches)
only controls whether pickers and filters show (`branch_options/1`).

### Maker-checker (change requests)

`Organization.maker_checker?` + `maker_checker_scopes` (Settings → Workspace). Covered actions carry
`change {Zippiker.Workflow.Changes.MakerChecker, scope: ...}` (employees, parties, products,
accounts, tax rates). When the scope is on, the change records a `Workflow.ChangeRequest` (the
action's inputs plus a before/after diff) in a `before_transaction` hook and stops the action with
`Workflow.Errors.ChangeRequested`; LiveViews show it with `change_requested/1`. The request goes
through the workflow engine (`:change_request`); on approval `ApplyApproval` replays the action as
the maker with `context: %{maker_checker_apply: true}`. The hook is atomic whenever it doesn't hold
the change (`atomic/3` returns `:not_atomic` only when holding), so actions stay atomic otherwise.

### Manufacturing

A `BillOfMaterials` makes `quantity` units of a stock-tracked product from components (stock-tracked
products) and operations (minutes at a `WorkCenter` with an hourly rate). `Manufacturing.Costing`
scales them for a quantity: requirements with stock shortages, labour/overhead and unit cost.
`ProductionOrder` (`MO-…`) goes draft → confirmed → in_progress → done (or cancelled before any
output). `record_output` refuses shortages, then records a `:production` stock operation (`PRD-…`):
components out at average cost, finished goods in at components + labour per unit. The ledger posts
the net (the labour/overhead) as DR inventory / CR "Manufacturing overhead applied"
(`:production_overhead`). The job card prints at `/manufacturing/orders/:id/print`.

### Customer & supplier portals

`Accounts.PortalAccess` (public schema, like invitations) links an outside user to one party of a
team as `:customer` or `:supplier`; admins invite from the party page (email with
`/portal/join/:token`, claimed by the signed-in user with that email in `PortalController`).
Portal pages (`/portal`, live session `:live_portal`) call `Zippiker.Portal` generic actions, which
verify the access (`Portal.Access.verify`) and read with authorization off, always filtered to
the access's party and never drafts: customers accept/decline quotes and see orders/invoices;
suppliers price RFQs and acknowledge purchase orders (`acknowledged_at`). Users with portals but
no workspace are sent to `/portal`.

### Modules, plans and the platform panel

- `Organization.enabled_modules` (`:crm`, `:sales`, `:purchasing`, `:inventory`, `:hr`, `:expenses`, `:manufacturing`, `:accounting`) hides navigation and
  blocks routes (`ZippikerWeb.Modules`, checked in `LiveUserAuth`). Data is kept.
- A plan sets modules and `seat_limit` on the workspace when assigned. Invitations respect
  the seat limit.
- Super admins (`users.super_admin?`) use `/platform`: workspaces, users, plans and billing.
  They can **impersonate** users (`PlatformController`, session `impersonator_id`) and
  **open any workspace** acting as admin. Both show a banner and are written to the audit log.
- Workspace owners and admins can impersonate their own members from Settings → Workspace or the
  employee page (`WorkspaceController.impersonate`): owners → admins and members, admins → members,
  never super admins or while already impersonating. Session `impersonation_origin` sends them back
  to their workspace when they stop.
- Grant the first super admin with `mix zippiker.super_admin someone@example.com`
  (`--revoke` to remove).

### End-user documentation

The in-app help center lives at `/help`. Each article is a template in
`lib/zippiker_web/live/help_articles/`, registered in `ZippikerWeb.HelpArticles`.
