# Demo workspace. Run with `mix run priv/repo/seeds.exs`.
# Sign in as demo@zippiker.com / password123. Safe to re-run: it skips if the user exists.

alias Zippiker.{Accounts, Crm, Extensibility, Parties}

require Ash.Query

email = "demo@zippiker.com"

if Accounts.User |> Ash.Query.filter(email == ^email) |> Ash.exists?(authorize?: false) do
  IO.puts("Demo user already exists, skipping seeds.")
else
  user =
    Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)

  user = Accounts.update_profile!(user, %{name: "Demo User"}, actor: user)
  org = Accounts.create_organization!(%{name: "Zippiker Demo", currency: "USD"}, actor: user)
  user = Ash.load!(user, :memberships, authorize?: false)
  opts = [actor: user, tenant: org]

  pipeline = Crm.seed_crm_defaults!(opts)
  stage = fn name -> Enum.find(pipeline.stages, &(&1.name == name)).id end

  Extensibility.create_custom_field!(
    %{entity: :organization, label: "Employees", type: :number, position: 0},
    opts
  )

  Extensibility.create_custom_field!(
    %{entity: :deal, label: "Plan", type: :select, options: ["Starter", "Growth", "Enterprise"]},
    opts
  )

  companies =
    for {name, industry, employees} <- [
          {"Globex", "Manufacturing", 1200},
          {"Initech", "Software", 85},
          {"Umbrella Health", "Healthcare", 4300},
          {"Stark Logistics", "Logistics", 640}
        ] do
      Parties.create_party!(
        %{
          kind: :organization,
          name: name,
          industry: industry,
          website: "https://#{String.downcase(String.replace(name, " ", ""))}.example",
          owner_id: user.id,
          custom_fields: %{"employees" => employees}
        },
        opts
      )
    end

  people =
    for {{first, last, title}, company} <-
          Enum.zip(
            [
              {"Hank", "Scorpio", "CEO"},
              {"Peter", "Gibbons", "Engineering Lead"},
              {"Alice", "Abernathy", "Head of Procurement"},
              {"Pepper", "Potts", "COO"}
            ],
            companies
          ) do
      Parties.create_party!(
        %{
          kind: :person,
          first_name: first,
          last_name: last,
          job_title: title,
          email:
            "#{String.downcase(first)}@#{String.downcase(String.replace(company.name, " ", ""))}.example",
          employer_id: company.id,
          owner_id: user.id
        },
        opts
      )
    end

  today = Date.utc_today()

  deals = [
    {"Globex platform rollout", 48_000, "Negotiation", 0, 12},
    {"Initech annual plan", 18_500, "Proposal", 1, 20},
    {"Umbrella pilot", 9_000, "Discovery", 2, 35},
    {"Stark fleet tracking", 32_000, "Qualified", 3, 45},
    {"Globex add-on seats", 6_500, "Won", 0, -3},
    {"Initech support upgrade", 4_200, "Lost", 1, -10}
  ]

  for {{title, amount, stage_name, index, close_in}, position} <- Enum.with_index(deals) do
    Crm.create_deal!(
      %{
        title: title,
        amount: Money.new!(:USD, amount),
        stage_id: stage.(stage_name),
        company_id: Enum.at(companies, index).id,
        party_id: Enum.at(people, index).id,
        owner_id: user.id,
        expected_close_on: Date.add(today, close_in),
        custom_fields: %{"plan" => Enum.at(["Starter", "Growth", "Enterprise"], rem(position, 3))}
      },
      opts
    )
  end

  for {first, last, company, source} <- [
        {"Marty", "McFly", "Hill Valley Co", :website},
        {"Ellen", "Ripley", "Weyland Corp", :referral},
        {"Dana", "Scully", nil, :event}
      ] do
    Crm.create_lead!(
      %{
        first_name: first,
        last_name: last,
        company_name: company,
        source: source,
        owner_id: user.id
      },
      opts
    )
  end

  Crm.log_activity!(
    %{
      kind: :call,
      body: "Walked Hank through the rollout plan. Wants pricing for 3 sites.",
      party_id: hd(people).id
    },
    opts
  )

  Crm.create_task!(
    %{
      title: "Send Globex revised quote",
      due_on: today,
      priority: :high,
      party_id: hd(people).id
    },
    opts
  )

  Crm.create_task!(%{title: "Book Initech demo", due_on: Date.add(today, 2)}, opts)
  Crm.create_task!(%{title: "Follow up with Umbrella", due_on: Date.add(today, -1)}, opts)

  IO.puts("Seeded demo workspace. Sign in as #{email} / password123")
end

# --- Sales demo data (Phase 2). Added to the demo workspace once. ---
alias Zippiker.{Catalog, Sales}

demo = Accounts.User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
demo = Ash.load!(demo, [memberships: :organization], authorize?: false)
org = hd(demo.memberships).organization
opts = [actor: demo, tenant: org]

if Catalog.list_products!(opts) == [] do
  entity = Accounts.default_legal_entity!(opts)

  Accounts.update_legal_entity!(
    entity,
    %{
      legal_name: "Zippiker Demo Ltd",
      tax_id: "TIN 102938475",
      email: "billing@zippiker.example",
      line1: "KG 7 Ave, Kigali Heights",
      city: "Kigali",
      country: "RW",
      invoice_footer: "Bank of Kigali · Account 0001-2345678-90 · Thank you for your business!"
    },
    opts
  )

  vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(18), default?: true}, opts)

  [platform, onboarding, support] =
    for {name, unit, price, kind} <- [
          {"Platform licence", "seat/month", 49, :service},
          {"Onboarding package", "package", 2_500, :service},
          {"Premium support", "month", 400, :service}
        ] do
      Catalog.create_product!(
        %{
          name: name,
          unit: unit,
          unit_price: Decimal.new(price),
          kind: kind,
          tax_rate_id: vat.id
        },
        opts
      )
    end

  line = fn product, quantity ->
    %{
      product_id: product.id,
      description: product.name,
      unit: product.unit,
      quantity: quantity,
      unit_price: product.unit_price,
      tax_rate_id: vat.id
    }
  end

  [globex | _] = Parties.list_parties!(:organization, %{query: "Globex"}, opts)
  [initech | _] = Parties.list_parties!(:organization, %{query: "Initech"}, opts)
  [umbrella | _] = Parties.list_parties!(:organization, %{query: "Umbrella"}, opts)

  # Accepted quote → invoiced → partly paid
  quote =
    Sales.create_quote!(
      %{
        customer_id: globex.id,
        lines: [line.(platform, 40), line.(onboarding, 1)],
        notes: "Annual plan, billed monthly."
      },
      opts
    )
    |> Sales.send_quote!(opts)
    |> Sales.accept_quote!(opts)

  invoice = quote.id |> Sales.invoice_quote!(opts) |> Sales.issue_invoice!(opts)

  Sales.record_payment!(
    %{invoice_id: invoice.id, amount: Money.new!(:USD, 2000), method: :bank_transfer},
    opts
  )

  # Sent quote awaiting an answer
  Sales.create_quote!(
    %{customer_id: initech.id, lines: [line.(platform, 15), line.(support, 12)]},
    opts
  )
  |> Sales.send_quote!(opts)

  # Overdue invoice
  Sales.create_invoice!(
    %{
      customer_id: umbrella.id,
      issued_on: Date.add(Date.utc_today(), -45),
      lines: [line.(onboarding, 1)]
    },
    opts
  )
  |> Sales.issue_invoice!(opts)

  IO.puts("Seeded sales demo data.")
end

# --- Platform (Phase 3): plans, a super admin, the demo workspace's books. ---
alias Zippiker.{Accounting, Platform}

if Platform.Plan |> Ash.Query.filter(code == "growth") |> Ash.exists?(authorize?: false) do
  IO.puts("Plans already exist, skipping platform seeds.")
else
  for {code, name, description, price, seats, modules, default?, position} <- [
        {"starter", "Starter", "For solo founders getting organized", 0, 2, [:crm], false, 0},
        {"growth", "Growth", "CRM and sales for growing teams", 12, 25, [:crm, :sales], true, 1},
        {"scale", "Scale", "The whole suite, including accounting", 24, nil,
         [:crm, :sales, :accounting], false, 2}
      ] do
    Platform.Plan
    |> Ash.Changeset.for_create(:create, %{
      code: code,
      name: name,
      description: description,
      price_per_seat: Decimal.new(price),
      seat_limit: seats,
      modules: modules,
      default?: default?,
      position: position
    })
    |> Ash.create!(authorize?: false)
  end

  # Any plan created on the fly before the price list existed is retired.
  Platform.Plan
  |> Ash.Query.filter(code == "standard")
  |> Ash.read!(authorize?: false)
  |> Enum.each(&Platform.update_plan!(&1, %{active?: false, default?: false}, authorize?: false))

  admin_email = "admin@zippiker.com"

  admin =
    Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: admin_email,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
    |> Accounts.update_profile!(%{name: "Platform Admin"}, authorize?: false)
    |> Accounts.set_super_admin!(true, authorize?: false)

  # The demo workspace runs the full suite.
  scale = Platform.Plan |> Ash.Query.filter(code == "scale") |> Ash.read_one!(authorize?: false)

  org.id
  |> Platform.ensure_subscription!(authorize?: false)
  |> Platform.change_plan!(
    %{plan_id: scale.id, status: :active, notes: "Demo workspace"},
    actor: admin
  )

  Platform.generate_billing_invoice!(org.id, actor: admin)
  |> Platform.mark_billing_invoice_paid!(%{}, actor: admin)

  IO.puts("Seeded plans. Platform admin: #{admin_email} / password123")
end

if Accounting.list_accounts!(opts) == [] do
  Accounting.sync_sales!(opts)
  account = fn code -> Enum.find(Accounting.list_accounts!(opts), &(&1.code == code)) end
  today = Date.utc_today()

  Accounting.create_journal_entry!(
    %{
      date: Date.add(today, -60),
      memo: "Owner investment",
      lines: [
        %{account_id: account.("1010").id, debit: "20000"},
        %{account_id: account.("3000").id, credit: "20000"}
      ]
    },
    opts
  )

  for {days_ago, memo, code, from, amount} <- [
        {40, "Office rent", "6100", "1010", "1800"},
        {35, "CRM & email tools", "6200", "1010", "240"},
        {20, "LinkedIn campaign", "6300", "2200", "650"},
        {10, "Office rent", "6100", "1010", "1800"},
        {4, "Client visit — Nairobi", "6400", "1020", "420"},
        {2, "Bank charges", "6500", "1010", "35"}
      ] do
    Accounting.record_expense!(
      %{
        date: Date.add(today, -days_ago),
        memo: memo,
        expense_account_id: account.(code).id,
        paid_from_account_id: account.(from).id,
        amount: amount
      },
      opts
    )
  end

  IO.puts("Seeded the demo books.")
end

# --- Purchasing & inventory (Phase 4). Added to the demo workspace once. ---
alias Zippiker.{Inventory, Purchasing}

all_modules = [:crm, :sales, :purchasing, :inventory, :accounting, :hr, :expenses, :manufacturing]

for plan <- Platform.list_plans!(authorize?: false), plan.code == "scale" do
  Platform.update_plan!(plan, %{modules: all_modules}, authorize?: false)
end

org = Accounts.get_organization!(org.id, authorize?: false)

if org.enabled_modules != all_modules do
  org = Accounts.set_plan_limits!(org, %{enabled_modules: all_modules}, authorize?: false)
  IO.puts("Enabled all modules for #{org.name}.")
end

if Purchasing.list_purchase_orders!(opts) == [] do
  today = Date.utc_today()
  vat = Enum.find(Catalog.list_tax_rates!(opts), & &1.default?)
  main = Inventory.default_warehouse!(opts)

  Inventory.create_warehouse!(
    %{name: "Showroom", code: "SHOW", address: "KN 4 Ave, Kigali"},
    opts
  )

  [router, camera, tablet] =
    for {name, sku, cost, price, reorder} <- [
          {"Fleet GPS tracker", "GPS-200", 38, 89, 10},
          {"Dash camera", "CAM-4K", 55, 129, 5},
          {"Driver tablet", "TAB-10", 140, 279, 3}
        ] do
      Catalog.create_product!(
        %{
          name: name,
          sku: sku,
          kind: :goods,
          unit: "pcs",
          track_inventory?: true,
          cost_price: Decimal.new(cost),
          unit_price: Decimal.new(price),
          reorder_level: Decimal.new(reorder),
          tax_rate_id: vat && vat.id
        },
        opts
      )
    end

  supplier =
    Parties.create_party!(
      %{kind: :organization, name: "Shenzhen Telematics Ltd", industry: "Electronics"},
      opts
    )

  office =
    Parties.create_party!(%{kind: :organization, name: "Kigali Office Rentals"}, opts)

  line = fn product, quantity ->
    %{
      product_id: product.id,
      description: product.name,
      unit: product.unit,
      quantity: quantity,
      unit_price: product.cost_price,
      tax_rate_id: vat && vat.id
    }
  end

  # Received and billed, half paid.
  po =
    Purchasing.create_purchase_order!(
      %{
        supplier_id: supplier.id,
        warehouse_id: main.id,
        issued_on: Date.add(today, -20),
        expected_on: Date.add(today, -12),
        lines: [line.(router, 60), line.(camera, 30)]
      },
      opts
    )
    |> Purchasing.place_purchase_order!(opts)
    |> Purchasing.receive_purchase_order!(%{date: Date.add(today, -12)}, opts)

  bill =
    po.id
    |> Purchasing.bill_purchase_order!(opts)
    |> Purchasing.update_bill!(%{supplier_reference: "STL-88231"}, opts)
    |> Purchasing.approve_bill!(opts)

  Purchasing.record_bill_payment!(
    %{bill_id: bill.id, amount: Money.new!(:USD, 2000), method: :bank_transfer},
    opts
  )

  # Ordered, partly arrived.
  po2 =
    Purchasing.create_purchase_order!(
      %{
        supplier_id: supplier.id,
        expected_on: Date.add(today, 5),
        lines: [line.(tablet, 8), line.(router, 40)]
      },
      opts
    )
    |> Purchasing.place_purchase_order!(opts)

  [tablet_line | _] = Ash.load!(po2, :lines, opts).lines
  Purchasing.receive_purchase_order!(po2, %{quantities: %{tablet_line.id => "2"}}, opts)

  # A service bill, overdue.
  rent = Enum.find(Accounting.list_accounts!(opts), &(&1.code == "6100"))

  Purchasing.create_bill!(
    %{
      supplier_id: office.id,
      supplier_reference: "KOR-0921",
      issued_on: Date.add(today, -40),
      due_on: Date.add(today, -10),
      lines: [
        %{
          description: "Office rent, September",
          quantity: "1",
          unit_price: "1800",
          expense_account_id: rent && rent.id
        }
      ]
    },
    opts
  )
  |> Purchasing.approve_bill!(opts)

  # Sold from stock: an order delivered and invoiced, one waiting to ship.
  [globex | _] = Parties.list_parties!(:organization, %{query: "Globex"}, opts)
  [stark | _] = Parties.list_parties!(:organization, %{query: "Stark"}, opts)

  sale_line = fn product, quantity ->
    %{
      product_id: product.id,
      description: product.name,
      unit: product.unit,
      quantity: quantity,
      unit_price: product.unit_price,
      tax_rate_id: vat && vat.id
    }
  end

  delivered =
    Sales.create_sales_order!(
      %{customer_id: stark.id, lines: [sale_line.(router, 25), sale_line.(camera, 27)]},
      opts
    )
    |> Sales.confirm_sales_order!(opts)
    |> Sales.deliver_sales_order!(opts)

  delivered.id |> Sales.invoice_sales_order!(opts) |> Sales.issue_invoice!(opts)

  Sales.create_sales_order!(
    %{
      customer_id: globex.id,
      expected_on: Date.add(today, 3),
      lines: [sale_line.(tablet, 2), sale_line.(router, 10)]
    },
    opts
  )
  |> Sales.confirm_sales_order!(opts)

  IO.puts("Seeded purchasing and inventory demo data.")
end

# --- HR (Phase 5). Added to the demo workspace once. ---
alias Zippiker.HR

if HR.list_employees!(%{}, opts) == [] do
  today = Date.utc_today()
  monday = Date.add(today, 8 - Date.day_of_week(today))

  annual = HR.create_leave_type!(%{name: "Annual leave", allowance_days: 20, color: :blue}, opts)

  sick =
    HR.create_leave_type!(
      %{name: "Sick leave", allowance_days: 10, requires_approval?: false, color: :rose},
      opts
    )

  HR.create_leave_type!(%{name: "Unpaid leave", paid?: false, color: :slate}, opts)

  [leadership, sales, ops] =
    for name <- ["Leadership", "Sales", "Operations"] do
      HR.create_department!(%{name: name}, opts)
    end

  ceo =
    HR.hire_employee!(
      %{
        first_name: "Demo",
        last_name: "User",
        email: "demo@zippiker.com",
        job_title: "Managing Director",
        department_id: leadership.id,
        user_id: demo.id,
        hire_date: ~D[2021-03-01],
        salary: 7500
      },
      opts
    )

  hire = fn first, last, title, department, manager, hired, salary ->
    HR.hire_employee!(
      %{
        first_name: first,
        last_name: last,
        email: "#{String.downcase(first)}@zippiker.example",
        job_title: title,
        department_id: department.id,
        manager_id: manager.id,
        hire_date: hired,
        salary: salary
      },
      opts
    )
  end

  head_sales = hire.("Aline", "Uwase", "Head of Sales", sales, ceo, ~D[2022-01-10], 4800)
  head_ops = hire.("Eric", "Mugisha", "Operations Manager", ops, ceo, ~D[2022-06-01], 4500)
  rep = hire.("Diane", "Ingabire", "Account Executive", sales, head_sales, ~D[2023-04-03], 2800)
  hire.("Patrick", "Habimana", "Account Executive", sales, head_sales, Date.add(today, -12), 2600)
  tech = hire.("Claude", "Niyonzima", "Installer", ops, head_ops, ~D[2024-02-19], 1900)
  hire.("Grace", "Mukamana", "Warehouse Lead", ops, head_ops, ~D[2023-09-11], 2100)

  HR.update_department!(sales, %{head_id: head_sales.id}, opts)
  HR.update_department!(ops, %{head_id: head_ops.id}, opts)
  HR.update_department!(leadership, %{head_id: ceo.id}, opts)

  # Diane is off next week (approved); Claude asks for time off (waiting for Eric).
  HR.request_leave!(
    %{
      employee_id: rep.id,
      leave_type_id: annual.id,
      start_date: monday,
      end_date: Date.add(monday, 4),
      reason: "Family wedding"
    },
    opts
  )
  |> HR.approve_leave!(opts)

  HR.request_leave!(
    %{
      employee_id: tech.id,
      leave_type_id: annual.id,
      start_date: Date.add(monday, 14),
      end_date: Date.add(monday, 16)
    },
    opts
  )

  HR.request_leave!(
    %{
      employee_id: head_ops.id,
      leave_type_id: sick.id,
      start_date: Date.add(monday, -7),
      end_date: Date.add(monday, -6)
    },
    opts
  )

  IO.puts("Seeded HR demo data.")
end

# --- Leave policies and a request for quotation (added later). Once each. ---
if HR.list_leave_policies!(opts) == [] and HR.list_leave_types!(opts) != [] do
  types = Map.new(HR.list_leave_types!(opts), &{&1.name, &1})

  standard =
    HR.create_leave_policy!(
      %{name: "Standard", description: "All staff", default?: true},
      opts
    )

  HR.set_leave_policy_rules!(
    standard,
    [
      %{leave_type_id: types["Annual leave"].id, days_per_year: "20", carry_over_days: "5"},
      %{leave_type_id: types["Sick leave"].id, days_per_year: "10"},
      %{leave_type_id: types["Unpaid leave"].id, days_per_year: ""}
    ],
    opts
  )

  senior =
    HR.create_leave_policy!(%{name: "Senior", description: "Heads of department"}, opts)

  HR.set_leave_policy_rules!(
    senior,
    [
      %{leave_type_id: types["Annual leave"].id, days_per_year: "25", carry_over_days: "10"},
      %{leave_type_id: types["Sick leave"].id, days_per_year: "15"},
      %{leave_type_id: types["Unpaid leave"].id, days_per_year: ""}
    ],
    opts
  )

  heads =
    for employee <- HR.list_employees!(%{}, opts),
        employee.job_title in ["Managing Director", "Head of Sales", "Operations Manager"],
        do: employee.id

  HR.assign_leave_policy!(senior, %{employee_ids: heads}, opts)
  IO.puts("Seeded leave policies.")
end

if Purchasing.list_rfqs!(opts) == [] and
     Catalog.list_products!(%{query: "Dash camera"}, opts) != [] do
  [camera] = Catalog.list_products!(%{query: "Dash camera"}, opts)
  [supplier | _] = Parties.list_parties!(:organization, %{query: "Shenzhen"}, opts)

  Purchasing.create_rfq!(
    %{
      supplier_id: supplier.id,
      valid_until: Date.add(Date.utc_today(), 7),
      notes: "Need 50 units by end of month. Please include shipping to Kigali.",
      lines: [
        %{
          product_id: camera.id,
          description: camera.name,
          unit: camera.unit,
          quantity: "50",
          unit_price: camera.cost_price
        }
      ]
    },
    opts
  )
  |> Purchasing.send_rfq!(opts)

  IO.puts("Seeded a request for quotation.")
end

# --- Expenses and approval workflows. Once. ---
alias Zippiker.{Expenses, Workflow}

if Expenses.list_expense_categories!(opts) == [] do
  Accounting.setup_books!(opts)
  accounts = Map.new(Accounting.list_accounts!(opts), &{&1.name, &1.id})

  [travel, meals, _software, _office] =
    for {name, account, receipt?} <- [
          {"Travel", "Travel", true},
          {"Meals & entertainment", "Other expenses", true},
          {"Software", "Software & subscriptions", false},
          {"Office supplies", "Other expenses", false}
        ] do
      Expenses.create_expense_category!(
        %{name: name, account_id: accounts[account], receipt_required?: receipt?},
        opts
      )
    end

  finance = Workflow.create_approval_group!(%{name: "Finance", member_ids: [demo.id]}, opts)

  Workflow.create_approval_workflow!(
    %{
      name: "Everyday expenses",
      steps: [%{approver_type: :manager, label: "Line manager"}]
    },
    opts
  )

  Workflow.create_approval_workflow!(
    %{
      name: "Large expenses",
      min_amount: "500000",
      steps: [
        %{approver_type: :manager, label: "Line manager"},
        %{approver_type: :group, group_id: finance.id, label: "Finance"},
        %{approver_type: :admins, label: "Director sign-off"}
      ]
    },
    opts
  )

  today = Date.utc_today()

  Expenses.create_expense_claim!(
    %{
      title: "Client visit to Musanze",
      items: [
        %{
          spent_on: Date.add(today, -3),
          category_id: travel.id,
          description: "Fuel",
          amount: "45000"
        },
        %{
          spent_on: Date.add(today, -3),
          category_id: meals.id,
          description: "Lunch with the client",
          merchant: "Virunga Lodge",
          amount: "38000"
        }
      ]
    },
    opts
  )

  paid =
    Expenses.create_expense_claim!(
      %{
        title: "Trade fair, Nairobi",
        items: [
          %{
            spent_on: Date.add(today, -20),
            category_id: travel.id,
            description: "Bus tickets",
            amount: "60000"
          },
          %{
            spent_on: Date.add(today, -19),
            category_id: meals.id,
            description: "Meals",
            amount: "25000"
          }
        ]
      },
      opts
    )
    |> Expenses.submit_expense_claim!(opts)

  if paid.status == :approved do
    Expenses.reimburse_expense_claim!(
      paid,
      %{reimbursed_on: Date.add(today, -10), reimbursed_from: :mobile_money},
      opts
    )
  end

  IO.puts("Seeded expense categories, approval workflows and claims.")
end

# --- Manufacturing. Once. ---
alias Zippiker.Manufacturing

if Manufacturing.list_work_centers!(opts) == [] do
  product = fn name, sku, cost, price ->
    Catalog.create_product!(
      %{
        name: name,
        sku: sku,
        kind: :goods,
        unit: "pcs",
        track_inventory?: true,
        cost_price: cost,
        unit_price: price
      },
      opts
    )
  end

  kit = product.("Solar lamp kit", "SLK-01", 0, 45000)
  panel = product.("Solar panel 5W", "SP-5W", 12000, 0)
  battery = product.("Li-ion battery 3.7V", "BAT-37", 6000, 0)
  bulb = product.("LED bulb 3W", "LED-3W", 1500, 0)
  casing = product.("Lamp casing", "CAS-01", 3000, 0)

  Inventory.record_stock_operation!(
    %{
      kind: :receipt,
      memo: "Opening stock of components",
      lines:
        Enum.map(
          [{panel, 40}, {battery, 40}, {bulb, 120}, {casing, 35}],
          fn {p, q} -> %{product_id: p.id, quantity: q, unit_cost: p.cost_price} end
        )
    },
    opts
  )

  assembly = Manufacturing.create_work_center!(%{name: "Assembly", hourly_rate: 3000}, opts)
  testing = Manufacturing.create_work_center!(%{name: "Quality control", hourly_rate: 2400}, opts)

  Manufacturing.create_bom!(
    %{
      product_id: kit.id,
      quantity: 1,
      components: [
        %{product_id: panel.id, quantity: 1, position: 0},
        %{product_id: battery.id, quantity: 1, position: 1},
        %{product_id: bulb.id, quantity: 3, position: 2},
        %{product_id: casing.id, quantity: 1, position: 3}
      ],
      operations: [
        %{
          name: "Wire and assemble",
          work_center_id: assembly.id,
          minutes: 25,
          position: 0,
          instructions: "Solder panel and battery leads; fit bulbs; close casing."
        },
        %{name: "Charge test", work_center_id: testing.id, minutes: 10, position: 1}
      ]
    },
    opts
  )

  today = Date.utc_today()

  Manufacturing.create_production_order!(
    %{product_id: kit.id, quantity: 20, due_on: Date.add(today, 7)},
    opts
  )
  |> Manufacturing.confirm_production_order!(opts)
  |> Manufacturing.record_production!(8, opts)

  Manufacturing.create_production_order!(
    %{
      product_id: kit.id,
      quantity: 10,
      planned_start: Date.add(today, 7),
      due_on: Date.add(today, 14)
    },
    opts
  )

  IO.puts("Seeded manufacturing demo data.")
end
