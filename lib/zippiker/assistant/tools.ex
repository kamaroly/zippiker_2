defmodule Zippiker.Assistant.Tools do
  @moduledoc """
  What the assistant can do, as Claude tool definitions plus their
  implementations. Every tool runs as the signed-in user (`actor`) in their
  workspace, so resource policies and roles decide what it may read or
  change. Read tools run straight away; write tools (`write?/1`) only run
  after the user approves them in the chat.
  """

  require Ash.Query

  alias Zippiker.{Catalog, Crm, HR, Parties, Purchasing, Sales}
  alias Zippiker.Reporting.Catalog, as: Reports

  @record_types ~w(contacts companies customers suppliers products leads deals quotes invoices bills employees)

  @writes ~w(create_contact create_lead create_task log_activity create_draft_quote create_draft_invoice log_time)

  @doc "Whether a tool changes data (and so needs the user's approval)."
  def write?(name), do: name in @writes

  @line_schema %{
    type: "array",
    description: "Document lines.",
    items: %{
      type: "object",
      properties: %{
        description: %{type: "string"},
        quantity: %{type: "number"},
        unit_price: %{type: "number", description: "Price per unit before tax."},
        product_id: %{type: "string", description: "Optional product id from search_records."}
      },
      required: ["description", "quantity", "unit_price"]
    }
  }

  @doc "Tool definitions for the Messages API (stable order, for prompt caching)."
  def definitions do
    [
      %{
        name: "search_records",
        description:
          "Search the workspace. Types: #{Enum.join(@record_types, ", ")}. Returns up to 10 matches with ids.",
        input_schema: %{
          type: "object",
          properties: %{
            type: %{type: "string", enum: @record_types},
            query: %{
              type: "string",
              description: "Words to match (name, number, email...). Empty lists recent ones."
            },
            status: %{
              type: "string",
              description: "Optional status filter, e.g. overdue, draft, open."
            }
          },
          required: ["type"]
        }
      },
      %{
        name: "get_record",
        description: "Full details of one record found with search_records.",
        input_schema: %{
          type: "object",
          properties: %{
            type: %{type: "string", enum: @record_types},
            id: %{type: "string"}
          },
          required: ["type", "id"]
        }
      },
      %{
        name: "list_reports",
        description:
          "The standard reports this user can run, with their keys and what period they take.",
        input_schema: %{type: "object", properties: %{}}
      },
      %{
        name: "run_report",
        description:
          "Runs a standard report (key from list_reports). Period reports take from/to dates, as-of reports take to. Dates are YYYY-MM-DD.",
        input_schema: %{
          type: "object",
          properties: %{
            key: %{type: "string"},
            from: %{type: "string"},
            to: %{type: "string"}
          },
          required: ["key"]
        }
      },
      %{
        name: "open_page",
        description:
          "Shows the user a link to a page of the app, e.g. /invoices/<id> or /reports/profit-and-loss.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "Path starting with /."},
            label: %{type: "string"}
          },
          required: ["path", "label"]
        }
      },
      %{
        name: "create_contact",
        description: "Adds a person or company to the address book (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            kind: %{type: "string", enum: ["person", "organization"]},
            name: %{type: "string", description: "Company name (organization)."},
            first_name: %{type: "string"},
            last_name: %{type: "string"},
            email: %{type: "string"},
            phone: %{type: "string"},
            roles: %{
              type: "array",
              items: %{type: "string", enum: ["customer", "supplier", "lead", "partner"]}
            }
          },
          required: ["kind"]
        }
      },
      %{
        name: "create_lead",
        description: "Adds a sales lead (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            first_name: %{type: "string"},
            last_name: %{type: "string"},
            company_name: %{type: "string"},
            email: %{type: "string"},
            phone: %{type: "string"},
            source: %{
              type: "string",
              enum: [
                "website",
                "referral",
                "event",
                "cold_outreach",
                "social",
                "advertising",
                "other"
              ]
            },
            notes: %{type: "string"}
          },
          required: ["first_name"]
        }
      },
      %{
        name: "create_task",
        description: "Creates a to-do, optionally about a contact (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            title: %{type: "string"},
            due_on: %{type: "string", description: "YYYY-MM-DD"},
            priority: %{type: "string", enum: ["low", "normal", "high"]},
            notes: %{type: "string"},
            party_id: %{type: "string", description: "Contact or company id."}
          },
          required: ["title"]
        }
      },
      %{
        name: "log_activity",
        description:
          "Records a call, email, meeting or note on a contact (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            party_id: %{type: "string"},
            kind: %{type: "string", enum: ["note", "call", "email", "meeting"]},
            subject: %{type: "string"},
            body: %{type: "string"}
          },
          required: ["party_id", "kind", "subject"]
        }
      },
      %{
        name: "create_draft_quote",
        description: "Creates a draft quote for a customer (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            customer_id: %{type: "string"},
            lines: @line_schema,
            notes: %{type: "string"}
          },
          required: ["customer_id", "lines"]
        }
      },
      %{
        name: "create_draft_invoice",
        description:
          "Creates a draft invoice for a customer; the user issues it themselves (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            customer_id: %{type: "string"},
            lines: @line_schema,
            notes: %{type: "string"}
          },
          required: ["customer_id", "lines"]
        }
      },
      %{
        name: "log_time",
        description: "Logs hours the user worked (needs the user's approval).",
        input_schema: %{
          type: "object",
          properties: %{
            date: %{type: "string", description: "YYYY-MM-DD"},
            hours: %{type: "number"},
            description: %{type: "string"},
            customer_id: %{type: "string"},
            billable: %{type: "boolean"},
            hourly_rate: %{type: "number"}
          },
          required: ["date", "hours"]
        }
      }
    ]
  end

  @doc "A one-line description of a write, for the approval card."
  def describe("create_contact", input, _ctx) do
    name =
      input["name"] ||
        Enum.join(Enum.reject([input["first_name"], input["last_name"]], &is_nil/1), " ")

    roles = input["roles"] || []

    "Add #{if input["kind"] == "person", do: "contact", else: "company"} #{name}" <>
      if(roles == [], do: "", else: " (#{Enum.join(roles, ", ")})")
  end

  def describe("create_lead", input, _ctx),
    do:
      "Add lead #{input["first_name"]} #{input["last_name"]}" <>
        if(input["company_name"], do: " at #{input["company_name"]}", else: "")

  def describe("create_task", input, _ctx),
    do:
      "Create task “#{input["title"]}”" <>
        if(input["due_on"], do: " due #{input["due_on"]}", else: "")

  def describe("log_activity", input, ctx),
    do: "Log #{input["kind"]} “#{input["subject"]}” on #{party_name(input["party_id"], ctx)}"

  def describe(name, input, ctx) when name in ["create_draft_quote", "create_draft_invoice"] do
    lines = input["lines"] || []

    net =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, Decimal.mult(decimal(line["quantity"]), decimal(line["unit_price"])))
      end)

    kind = if name == "create_draft_quote", do: "quote", else: "invoice"

    "Create a draft #{kind} for #{party_name(input["customer_id"], ctx)}: " <>
      "#{length(lines)} line(s), #{Decimal.round(net, 2)} #{ctx.organization.currency} before tax"
  end

  def describe("log_time", input, _ctx),
    do:
      "Log #{input["hours"]} h on #{input["date"]}" <>
        if(input["description"], do: ": #{input["description"]}", else: "")

  def describe(name, _input, _ctx), do: name

  @doc """
  Runs a tool. Returns `{:ok, result}` (JSON-encodable) or
  `{:error, message}`; both go back to Claude as the tool result.
  """
  def run(name, input, ctx) do
    do_run(name, input || %{}, ctx)
  rescue
    _error in Ash.Error.Forbidden -> {:error, "The user's role doesn't allow this."}
    error in Ash.Error.Invalid -> {:error, "Invalid: " <> Exception.message(error)}
  end

  # Reads

  defp do_run("search_records", %{"type" => type} = input, ctx) when type in @record_types do
    with :ok <- allowed(type, ctx) do
      query = input["query"] || ""
      status = input["status"]
      page = [page: [limit: 10]]

      results =
        case type do
          "contacts" ->
            Parties.list_parties!(:person, %{query: query}, opts(ctx) ++ page)

          "companies" ->
            Parties.list_parties!(:organization, %{query: query}, opts(ctx) ++ page)

          "customers" ->
            Parties.list_parties!(nil, %{query: query, role: :customer}, opts(ctx) ++ page)

          "suppliers" ->
            Parties.list_parties!(nil, %{query: query, role: :supplier}, opts(ctx) ++ page)

          "products" ->
            Catalog.list_products!(%{query: query}, opts(ctx) ++ page)

          "leads" ->
            Crm.list_leads!(%{query: query}, opts(ctx) ++ page)

          "deals" ->
            Crm.list_deals!(
              with_status(%{query: query}, status, ~w(open won lost)),
              opts(ctx) ++ page
            )

          "quotes" ->
            Sales.list_quotes!(%{query: query}, opts(ctx) ++ page)

          "invoices" ->
            Sales.list_invoices!(
              with_status(%{query: query}, status, ~w(draft issued paid void overdue)),
              opts(ctx) ++ page
            )

          "bills" ->
            Purchasing.list_bills!(
              with_status(%{query: query}, status, ~w(draft open paid void overdue)),
              opts(ctx) ++ page
            )

          "employees" ->
            HR.list_employees!(
              %{query: query},
              Keyword.put(opts(ctx) ++ page, :load, [:name, :email])
            )
        end

      {:ok, %{results: Enum.map(results(results), &summary(type, &1))}}
    end
  end

  defp do_run("get_record", %{"type" => type, "id" => id}, ctx) when type in @record_types do
    with :ok <- allowed(type, ctx) do
      {:ok, details(type, id, ctx)}
    end
  end

  defp do_run("list_reports", _input, ctx) do
    {:ok,
     %{
       reports:
         for report <- Reports.visible(ctx.organization, ctx.permissions) do
           %{
             key: report.key,
             title: report.title,
             period: report.period,
             about: report.description
           }
         end
     }}
  end

  defp do_run("run_report", %{"key" => key} = input, ctx) do
    if Enum.any?(Reports.visible(ctx.organization, ctx.permissions), &(&1.key == key)) do
      args =
        %{from: date(input["from"]), to: date(input["to"])}
        |> Map.reject(fn {_k, v} -> is_nil(v) end)

      report = Zippiker.Reporting.run_report!(key, args, opts(ctx))
      rows = report.rows

      {:ok,
       %{
         title: report.title,
         from: report.from && Date.to_iso8601(report.from),
         to: report.to && Date.to_iso8601(report.to),
         currency: ctx.organization.currency,
         columns: Enum.map(report.columns, & &1.label),
         rows:
           rows
           |> Enum.take(80)
           |> Enum.map(fn row -> [to_string(row.kind) | Enum.map(row.cells, &cell/1)] end),
         truncated: length(rows) > 80,
         note: report.note,
         link: "/reports/#{key}"
       }}
    else
      {:error, "No report with that key is available to this user. Call list_reports."}
    end
  end

  defp do_run("open_page", %{"path" => "/" <> rest} = input, _ctx) do
    if String.starts_with?(rest, "/") or String.contains?(rest, ["://", "\\"]),
      do: {:error, "Use an app path like /invoices."},
      else: {:ok, %{shown: true, path: "/" <> rest, label: input["label"]}}
  end

  defp do_run("open_page", _input, _ctx), do: {:error, "Use an app path starting with /."}

  # Writes (run only after the user approves)

  defp do_run("create_contact", input, ctx) do
    attrs =
      %{
        kind: if(input["kind"] == "person", do: :person, else: :organization),
        name: input["name"],
        first_name: input["first_name"],
        last_name: input["last_name"],
        email: input["email"],
        phone: input["phone"],
        roles:
          for(
            role <- input["roles"] || [],
            role in ~w(customer supplier lead partner),
            do: String.to_existing_atom(role)
          ),
        owner_id: ctx.actor.id
      }
      |> compact()

    party = Parties.create_party!(attrs, opts(ctx))
    {:ok, %{id: party.id, name: party.name, link: party_path(party)}}
  end

  defp do_run("create_lead", input, ctx) do
    attrs =
      %{
        first_name: input["first_name"],
        last_name: input["last_name"],
        company_name: input["company_name"],
        email: input["email"],
        phone: input["phone"],
        notes: input["notes"],
        source:
          input["source"] in ~w(website referral event cold_outreach social advertising other) &&
            String.to_existing_atom(input["source"]),
        owner_id: ctx.actor.id
      }
      |> compact()

    lead = Crm.create_lead!(attrs, opts(ctx))
    {:ok, %{id: lead.id, link: "/leads/#{lead.id}"}}
  end

  defp do_run("create_task", input, ctx) do
    attrs =
      %{
        title: input["title"],
        notes: input["notes"],
        due_on: date(input["due_on"]),
        priority:
          input["priority"] in ~w(low normal high) && String.to_existing_atom(input["priority"]),
        party_id: input["party_id"],
        assignee_id: ctx.actor.id
      }
      |> compact()

    task = Crm.create_task!(attrs, opts(ctx))
    {:ok, %{id: task.id, link: "/tasks"}}
  end

  defp do_run("log_activity", input, ctx) do
    activity =
      Crm.log_activity!(
        compact(%{
          party_id: input["party_id"],
          kind:
            if(input["kind"] in ~w(note call email meeting),
              do: String.to_existing_atom(input["kind"]),
              else: :note
            ),
          subject: input["subject"],
          body: input["body"]
        }),
        opts(ctx)
      )

    {:ok, %{id: activity.id}}
  end

  defp do_run("create_draft_quote", input, ctx) do
    quote = Sales.create_quote!(document(input), opts(ctx))
    {:ok, %{id: quote.id, number: quote.number, link: "/quotes/#{quote.id}"}}
  end

  defp do_run("create_draft_invoice", input, ctx) do
    invoice = Sales.create_invoice!(document(input), opts(ctx))
    {:ok, %{id: invoice.id, link: "/invoices/#{invoice.id}", status: "draft"}}
  end

  defp do_run("log_time", input, ctx) do
    activity =
      HR.log_time!(
        compact(%{
          date: date(input["date"]) || Date.utc_today(),
          hours: decimal(input["hours"]),
          description: input["description"],
          customer_id: input["customer_id"],
          billable?: input["billable"] == true,
          hourly_rate: input["hourly_rate"] && decimal(input["hourly_rate"])
        }),
        opts(ctx)
      )

    {:ok, %{id: activity.id, link: "/hr/time"}}
  end

  defp do_run(name, _input, _ctx), do: {:error, "Unknown tool or missing input: #{name}"}

  # Helpers

  defp opts(ctx), do: [actor: ctx.actor, tenant: ctx.organization]

  @views %{
    "contacts" => "view.contacts",
    "companies" => "view.contacts",
    "customers" => "view.sales",
    "suppliers" => "view.purchasing",
    "products" => "view.sales",
    "leads" => "view.crm",
    "deals" => "view.crm",
    "quotes" => "view.sales",
    "invoices" => "view.sales",
    "bills" => "view.purchasing",
    "employees" => "view.hr"
  }

  @modules %{
    "customers" => :sales,
    "suppliers" => :purchasing,
    "products" => :sales,
    "leads" => :crm,
    "deals" => :crm,
    "quotes" => :sales,
    "invoices" => :sales,
    "bills" => :purchasing,
    "employees" => :hr
  }

  defp allowed(type, ctx) do
    module = @modules[type]
    key = @views[type]

    cond do
      module && module not in (ctx.organization.enabled_modules || []) ->
        {:error, "The #{module} module isn't enabled in this workspace."}

      ctx.permissions == :all ->
        :ok

      is_struct(ctx.permissions, MapSet) and MapSet.member?(ctx.permissions, key) ->
        :ok

      true ->
        {:error, "The user's role doesn't include #{type}."}
    end
  end

  defp results(%{results: results}), do: results
  defp results(list) when is_list(list), do: list

  defp with_status(args, status, allowed) do
    if status in allowed, do: Map.put(args, :status, String.to_existing_atom(status)), else: args
  end

  defp summary(type, record) when type in ~w(contacts companies customers suppliers) do
    %{
      id: record.id,
      name: record.name,
      kind: record.kind,
      email: record.email && to_string(record.email),
      phone: record.phone,
      roles: record.roles,
      link: party_path(record)
    }
  end

  defp summary("products", p),
    do: %{
      id: p.id,
      name: p.name,
      sku: p.sku,
      kind: p.kind,
      unit_price: cell(p.unit_price),
      unit: p.unit,
      link: "/products"
    }

  defp summary("leads", l),
    do: %{
      id: l.id,
      name: l.name,
      company: l.company_name,
      status: l.status,
      email: l.email && to_string(l.email),
      link: "/leads/#{l.id}"
    }

  defp summary("deals", d),
    do: %{
      id: d.id,
      title: d.title,
      amount: cell(d.amount),
      status: d.status,
      expected_close_on: cell(d.expected_close_on),
      link: "/deals/#{d.id}"
    }

  defp summary(type, doc) when type in ~w(quotes invoices bills) do
    path = %{"quotes" => "/quotes", "invoices" => "/invoices", "bills" => "/bills"}[type]

    %{
      id: doc.id,
      number: doc.number,
      status: doc.status,
      issued_on: cell(doc.issued_on),
      due_on: cell(Map.get(doc, :due_on)),
      total: cell(doc.total),
      amount_paid: cell(Map.get(doc, :amount_paid)),
      party: party_label(Map.get(doc, :customer) || Map.get(doc, :supplier)),
      link: "#{path}/#{doc.id}"
    }
  end

  defp summary("employees", e),
    do: %{
      id: e.id,
      name: e.name,
      job_title: e.job_title,
      email: e.email && to_string(e.email),
      status: e.status,
      link: "/hr/employees/#{e.id}"
    }

  defp details(type, id, ctx) when type in ~w(contacts companies customers suppliers) do
    party = Parties.get_party!(id, opts(ctx) ++ [load: [:addresses, :employer]])

    activities =
      Zippiker.Crm.Activity
      |> Ash.Query.filter(party_id == ^id)
      |> Ash.Query.sort(occurred_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!(opts(ctx))

    Map.merge(summary(type, party), %{
      company: party_label(party.employer),
      job_title: party.job_title,
      tax_id: party.tax_id,
      tags: party.tags,
      addresses: Enum.map(party.addresses, &Map.take(&1, [:kind, :line1, :city, :country])),
      recent_activity:
        Enum.map(activities, &%{kind: &1.kind, subject: &1.subject, at: cell(&1.occurred_at)})
    })
  end

  defp details("invoices", id, ctx) do
    invoice = Sales.get_invoice!(id, opts(ctx) ++ [load: [:customer, :lines, :amount_due]])

    Map.merge(summary("invoices", invoice), %{
      amount_due: cell(invoice.amount_due),
      lines: Enum.map(invoice.lines, &line/1),
      notes: invoice.notes
    })
  end

  defp details("quotes", id, ctx) do
    quote = Sales.get_quote!(id, opts(ctx) ++ [load: [:customer, :lines]])
    Map.put(summary("quotes", quote), :lines, Enum.map(quote.lines, &line/1))
  end

  defp details("bills", id, ctx) do
    bill = Purchasing.get_bill!(id, opts(ctx) ++ [load: [:supplier, :lines]])
    Map.put(summary("bills", bill), :lines, Enum.map(bill.lines, &line/1))
  end

  defp details("products", id, ctx) do
    product = Catalog.get_product!(id, opts(ctx) ++ [load: [:on_hand]])

    Map.merge(summary("products", product), %{
      on_hand: cell(product.on_hand),
      description: product.description
    })
  end

  defp details("leads", id, ctx), do: summary("leads", Crm.get_lead!(id, opts(ctx)))

  defp details("deals", id, ctx) do
    deal = Crm.get_deal!(id, opts(ctx) ++ [load: [:stage, :party]])

    Map.merge(summary("deals", deal), %{
      stage: deal.stage && deal.stage.name,
      contact: party_label(deal.party),
      description: deal.description
    })
  end

  defp details("employees", id, ctx),
    do: summary("employees", HR.get_employee!(id, opts(ctx) ++ [load: [:name, :email]]))

  defp line(line),
    do: %{
      description: line.description,
      quantity: cell(line.quantity),
      unit_price: cell(line.unit_price),
      tax_percent: cell(line.tax_percent),
      amount: cell(line.subtotal)
    }

  defp document(input) do
    %{
      customer_id: input["customer_id"],
      notes: input["notes"],
      lines:
        for line <- input["lines"] || [] do
          compact(%{
            description: line["description"],
            quantity: decimal(line["quantity"]),
            unit_price: decimal(line["unit_price"]),
            product_id: line["product_id"]
          })
        end
    }
    |> compact()
  end

  defp party_name(nil, _ctx), do: "—"

  defp party_name(id, ctx) do
    case Parties.get_party(id, opts(ctx)) do
      {:ok, party} -> party.name
      _ -> "an unknown contact"
    end
  end

  defp party_label(%{name: name}), do: name
  defp party_label(_), do: nil

  defp party_path(%{kind: :person, id: id}), do: "/contacts/#{id}"
  defp party_path(%{id: id}), do: "/companies/#{id}"

  defp compact(map), do: Map.reject(map, fn {_k, v} -> v in [nil, false, ""] end)

  defp date(nil), do: nil

  defp date(value) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp decimal(nil), do: Decimal.new(0)
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp decimal(value) when is_binary(value), do: Decimal.new(value)
  defp decimal(%Decimal{} = value), do: value

  defp cell(nil), do: nil
  defp cell(%Money{} = money), do: Money.to_string!(money)
  defp cell(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp cell(%Date{} = d), do: Date.to_iso8601(d)
  defp cell(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp cell(value), do: value
end
