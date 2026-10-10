defmodule ZippikerWeb.DocumentLive.Form do
  @moduledoc """
  Create / edit page shared by every priced document: quotes, sales orders
  and invoices (to customers), purchase orders and bills (from suppliers).
  Same layout (party, dates, line items with live totals); `@kinds` says
  what differs.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounting, Catalog, Crm, Extensibility, Inventory, Purchasing, Sales}

  @kinds %{
    quote: %{
      resource: Sales.Quote,
      get: &Sales.get_quote!/2,
      party: :customer_id,
      title: "quote",
      plural: "Quotes",
      list: "/quotes",
      nav: :quotes,
      entity: :quote
    },
    sales_order: %{
      resource: Sales.SalesOrder,
      get: &Sales.get_sales_order!/2,
      party: :customer_id,
      title: "order",
      plural: "Orders",
      list: "/orders",
      nav: :sales_orders,
      entity: nil
    },
    invoice: %{
      resource: Sales.Invoice,
      get: &Sales.get_invoice!/2,
      party: :customer_id,
      title: "invoice",
      plural: "Invoices",
      list: "/invoices",
      nav: :invoices,
      entity: :invoice
    },
    rfq: %{
      resource: Purchasing.Rfq,
      get: &Purchasing.get_rfq!/2,
      party: :supplier_id,
      title: "request for quotation",
      plural: "Requests for quotation",
      list: "/rfqs",
      nav: :rfqs,
      entity: nil
    },
    purchase_order: %{
      resource: Purchasing.PurchaseOrder,
      get: &Purchasing.get_purchase_order!/2,
      party: :supplier_id,
      title: "purchase order",
      plural: "Purchase orders",
      list: "/purchase-orders",
      nav: :purchase_orders,
      entity: nil
    },
    bill: %{
      resource: Purchasing.Bill,
      get: &Purchasing.get_bill!/2,
      party: :supplier_id,
      title: "bill",
      plural: "Bills",
      list: "/bills",
      nav: :bills,
      entity: nil
    }
  }

  @impl true
  def mount(params, _session, socket) do
    kind = kind(socket.assigns.live_action)
    config = Map.fetch!(@kinds, kind)
    opts = ash_opts(socket)
    tax_rates = Catalog.list_tax_rates!(opts)
    products = Catalog.list_products!(%{active_only?: true}, opts ++ [page: [limit: 500]]).results

    socket =
      socket
      |> assign(kind: kind, config: config, tax_rates: tax_rates, products: products)
      |> assign(:purchase?, config.party == :supplier_id)
      |> assign(:product_options, Enum.map(products, &{&1.name, &1.id}))
      |> assign(
        :tax_options,
        Enum.map(tax_rates, &{"#{&1.name} #{Decimal.normalize(&1.rate)}%", &1.id})
      )
      |> assign(:account_options, account_options(kind, opts))
      |> assign(:warehouse_options, warehouse_options(kind, socket.assigns, opts))
      |> assign(
        :definitions,
        if(config.entity, do: Extensibility.list_custom_fields!(config.entity, opts), else: [])
      )
      |> assign(:members, member_options(socket.assigns))
      |> assign_document(params)

    {:ok, socket}
  end

  defp kind(action) do
    action |> to_string() |> String.replace(~r/^(new|edit)_/, "") |> String.to_existing_atom()
  end

  # Bills say what each non-stock line was for.
  defp account_options(:bill, opts) do
    for account <- Accounting.list_accounts!(%{active_only?: true}, opts),
        account.type in [:expense, :asset],
        is_nil(account.system_key) or account.system_key == :expense,
        do: {"#{account.code} · #{account.name}", account.id}
  end

  defp account_options(_kind, _opts), do: nil

  defp warehouse_options(kind, assigns, opts) when kind in [:sales_order, :purchase_order] do
    if module?(assigns, :inventory),
      do: Enum.map(Inventory.list_warehouses!(%{active_only?: true}, opts), &{&1.name, &1.id}),
      else: nil
  end

  defp warehouse_options(_kind, _assigns, _opts), do: nil

  defp assign_document(socket, %{"id" => id}) do
    document = socket.assigns.config.get.(id, ash_opts(socket) ++ [load: [:lines]])

    form =
      document
      |> AshPhoenix.Form.for_update(:update,
        as: "document",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    socket
    |> assign(document: document, page_title: "Edit #{document.number || "draft"}")
    |> assign_form(form)
  end

  defp assign_document(socket, params) do
    defaults = defaults(socket, params)
    {lines, defaults} = Map.pop(defaults, "lines")

    form =
      socket.assigns.config.resource
      |> AshPhoenix.Form.for_create(:create,
        as: "document",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: defaults
      )

    form =
      case lines do
        nil ->
          AshPhoenix.Form.add_form(form, :lines, params: blank_line())

        lines ->
          lines
          |> Enum.sort_by(fn {index, _line} -> String.to_integer(index) end)
          |> Enum.reduce(form, fn {_index, line}, form ->
            AshPhoenix.Form.add_form(form, :lines, params: line)
          end)
      end

    title =
      if params["copy"],
        do: "Copy of a #{socket.assigns.config.title}",
        else: "New #{socket.assigns.config.title}"

    socket
    |> assign(document: nil, page_title: String.capitalize(title))
    |> assign_form(form)
  end

  # Prefill from ?copy= (duplicate), ?deal_id=, ?customer_id= or ?supplier_id=.
  defp defaults(socket, %{"copy" => id} = params) do
    base = defaults(socket, Map.delete(params, "copy"))

    case Ash.get(socket.assigns.config.resource, id, ash_opts(socket) ++ [load: [:lines]]) do
      {:ok, source} -> Map.merge(base, copied(source, socket.assigns.config.party))
      _ -> base
    end
  end

  defp defaults(socket, params) do
    today = Date.utc_today()

    base = %{
      "owner_id" => socket.assigns.current_user.id,
      "issued_on" => Date.to_iso8601(today)
    }

    base =
      if socket.assigns.kind == :quote,
        do: Map.put(base, "valid_until", today |> Date.add(30) |> Date.to_iso8601()),
        else: base

    case params do
      %{"deal_id" => deal_id} ->
        case Crm.get_deal(deal_id, ash_opts(socket)) do
          {:ok, deal} ->
            Map.merge(base, %{
              "deal_id" => deal.id,
              "customer_id" => deal.company_id || deal.party_id,
              "contact_id" => deal.party_id
            })

          _ ->
            base
        end

      %{"customer_id" => customer_id} ->
        Map.put(base, "customer_id", customer_id)

      %{"supplier_id" => supplier_id} ->
        Map.put(base, "supplier_id", supplier_id)

      _ ->
        base
    end
  end

  @line_fields ~w(product_id description quantity unit unit_price discount_percent tax_rate_id expense_account_id)a

  # A duplicate keeps the party, notes and lines; dates, numbers and status start fresh.
  defp copied(source, party_field) do
    lines =
      source.lines
      |> Enum.with_index()
      |> Map.new(fn {line, index} ->
        {to_string(index),
         for(
           field <- @line_fields,
           Map.has_key?(line, field),
           value = Map.get(line, field),
           not is_nil(value),
           into: %{},
           do: {to_string(field), to_param(value)}
         )}
      end)

    %{
      to_string(party_field) => Map.get(source, party_field),
      "contact_id" => Map.get(source, :contact_id),
      "warehouse_id" => Map.get(source, :warehouse_id),
      "notes" => source.notes,
      "lines" => lines
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp to_param(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp to_param(value), do: to_string(value)

  @impl true
  def handle_event("validate", %{"document" => params}, socket) do
    params = autofill_products(params, socket.assigns)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign_form(socket, form)}
  end

  def handle_event("add_line", _params, socket) do
    {:noreply,
     assign_form(
       socket,
       AshPhoenix.Form.add_form(socket.assigns.form, :lines, params: blank_line())
     )}
  end

  def handle_event("remove_line", %{"path" => path}, socket) do
    {:noreply, assign_form(socket, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("save", %{"document" => params}, socket) do
    params = autofill_products(params, socket.assigns)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, document} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{String.capitalize(socket.assigns.config.title)} saved")
         |> push_navigate(to: show_path(socket.assigns.config, document))}

      {:error, form} ->
        {:noreply, assign_form(socket, form)}
    end
  end

  defp assign_form(socket, form) do
    form = to_form(form)

    preview =
      ZippikerWeb.SalesComponents.preview(AshPhoenix.Form.params(form), socket.assigns.tax_rates)

    assign(socket, form: form, preview: preview)
  end

  # Picking a product on a line with no description fills description, unit,
  # price (selling price on sales documents, cost on purchases) and tax.
  defp autofill_products(%{"lines" => lines} = params, assigns) when is_map(lines) do
    by_id = Map.new(assigns.products, &{&1.id, &1})

    lines =
      Map.new(lines, fn {index, line} ->
        case {Map.get(by_id, line["product_id"]), line["description"]} do
          {%{} = product, description} when description in [nil, ""] ->
            price = if assigns.purchase?, do: product.cost_price, else: product.unit_price

            {index,
             Map.merge(line, %{
               "description" => product.name,
               "unit" => product.unit,
               "unit_price" => Decimal.to_string(price, :normal),
               "tax_rate_id" => product.tax_rate_id || ""
             })}

          _ ->
            {index, line}
        end
      end)

    Map.put(params, "lines", lines)
  end

  defp autofill_products(params, _assigns), do: params

  defp blank_line, do: %{"quantity" => "1", "unit_price" => "0", "discount_percent" => "0"}

  defp show_path(config, document), do: "#{config.list}/#{document.id}"

  defp cancel_path(config, nil), do: config.list
  defp cancel_path(config, document), do: show_path(config, document)
end
