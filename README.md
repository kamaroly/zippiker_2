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

Every tenant resource uses attribute multitenancy on `organization_id` and the
`ActorIsMember` / `ActorIsAdmin` policy checks. LiveViews pass `ash_opts(socket)`
(`actor` + `tenant`) to every call.

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
leave; their manager's user approves (`LeaveRequest` policies; never yourself). Leave counts Mon–Fri
days and is checked against the employee's entitlement (`HR.Entitlement`): their `LeavePolicy` (or the
default policy) lists the leave types, days per year and carry-over; with no policies, each
`LeaveType.allowance_days` applies. Salary and personal fields
are protected by field policies (admins and the employee only).

### Modules, plans and the platform panel

- `Organization.enabled_modules` (`:crm`, `:sales`, `:purchasing`, `:inventory`, `:hr`, `:accounting`) hides navigation and
  blocks routes (`ZippikerWeb.Modules`, checked in `LiveUserAuth`). Data is kept.
- A plan sets modules and `seat_limit` on the workspace when assigned. Invitations respect
  the seat limit.
- Super admins (`users.super_admin?`) use `/platform`: workspaces, users, plans and billing.
  They can **impersonate** users (`PlatformController`, session `impersonator_id`) and
  **open any workspace** acting as admin. Both show a banner and are written to the audit log.
- Grant the first super admin with `mix zippiker.super_admin someone@example.com`
  (`--revoke` to remove).

### End-user documentation

The in-app help center lives at `/help`. Each article is a template in
`lib/zippiker_web/live/help_articles/`, registered in `ZippikerWeb.HelpArticles`.
