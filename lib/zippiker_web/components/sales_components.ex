defmodule ZippikerWeb.SalesComponents do
  @moduledoc "Quote and invoice building blocks: status badges, line editor, totals and the printable document."
  use Phoenix.Component
  use ZippikerWeb, :verified_routes

  import ZippikerWeb.CoreComponents

  alias Zippiker.Sales.Pricing
  alias ZippikerWeb.Format

  attr :status, :atom, required: true

  def quote_status(assigns) do
    ~H"""
    <.badge color={%{draft: :slate, sent: :blue, accepted: :emerald, declined: :rose}[@status]}>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  @doc """
  One-click print buttons for a document page: the document itself (when
  `document` is given) and, next to it, its delivery or goods received notes:
  the note directly when there is one, all of them (one per page) when there
  are several.
  """
  attr :id, :string, required: true
  attr :document, :string, default: nil, doc: "print path of the document itself"
  attr :notes, :list, default: []
  attr :kind, :atom, required: true, values: [:delivery, :goods_receipt]

  def print_buttons(assigns) do
    {single, plural, base} =
      case assigns.kind do
        :delivery -> {"Delivery note", "Delivery notes", "/deliveries"}
        :goods_receipt -> {"Goods received note", "Goods received notes", "/goods-receipts"}
      end

    {label, path} =
      case assigns.notes do
        [] ->
          {nil, nil}

        [note] ->
          {single, "#{base}/#{note.id}/print"}

        notes ->
          {"#{plural} (#{length(notes)})",
           "#{base}/print?ids=#{Enum.map_join(notes, ",", & &1.id)}"}
      end

    assigns = assign(assigns, note_label: label, note_path: path)

    ~H"""
    <.button :if={@document} navigate={@document} id={@id}>
      <.icon name="hero-printer-micro" /> Print
    </.button>
    <.button :if={@note_path} navigate={@note_path} id={"#{@id}-notes"}>
      <.icon name="hero-clipboard-document-list-micro" /> {@note_label}
    </.button>
    """
  end

  @doc "One document in a party's transactions list."
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :total, :any, default: nil
  slot :inner_block, doc: "status badge"

  def transaction_row(assigns) do
    ~H"""
    <li id={@id}>
      <.link navigate={@path} class="flex items-center gap-3 py-2.5 hover:opacity-80">
        <.icon name={@icon} class="size-4 text-muted" />
        <span class="flex-1 truncate text-sm text-ink">{@label}</span>
        {render_slot(@inner_block)}
        <span class="tabular text-sm font-medium text-ink">{Format.money(@total)}</span>
      </.link>
    </li>
    """
  end

  attr :status, :atom, required: true

  def order_status(assigns) do
    ~H"""
    <.badge color={
      %{
        draft: :slate,
        confirmed: :blue,
        partially_delivered: :amber,
        delivered: :emerald,
        cancelled: :rose
      }[@status]
    }>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  @doc "Invoice badge; issued invoices show Overdue or Partially paid when relevant."
  attr :invoice, :map, required: true

  def invoice_status(assigns) do
    assigns = assign(assigns, :label, invoice_label(assigns.invoice))

    ~H"""
    <.badge color={elem(@label, 1)}>{elem(@label, 0)}</.badge>
    """
  end

  defp invoice_label(%{status: :issued} = invoice) do
    cond do
      Map.get(invoice, :overdue?) == true -> {"Overdue", :rose}
      invoice.amount_paid && Money.positive?(invoice.amount_paid) -> {"Partially paid", :amber}
      true -> {"Open", :blue}
    end
  end

  defp invoice_label(%{status: :draft}), do: {"Draft", :slate}
  defp invoice_label(%{status: :paid}), do: {"Paid", :emerald}
  defp invoice_label(%{status: :void}), do: {"Void", :slate}

  @doc """
  Editable line items for a quote/invoice form. Pushes `add_line` and
  `remove_line` (with `path`); product changes are handled by the form's
  `validate` event, which fills in description, price and tax.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :products, :list, required: true, doc: "{name, id} options"
  attr :tax_rates, :list, required: true, doc: "{label, id} options"

  attr :accounts, :list,
    default: nil,
    doc: "{label, id} expense accounts; adds an Account column (bills)"

  attr :preview, :map, required: true, doc: "Pricing per line index plus :totals"
  attr :currency, :string, required: true

  def line_items(assigns) do
    ~H"""
    <div id="line-items" class="overflow-x-auto rounded-2xl border border-line bg-surface shadow-card">
      <table class="w-full min-w-[860px] text-sm">
        <thead>
          <tr class="border-b border-line text-left text-xs text-muted">
            <th class="w-48 px-3 py-2.5 font-medium">Product</th>
            <th class="px-3 py-2.5 font-medium">Description</th>
            <th class="w-20 px-3 py-2.5 font-medium">Qty</th>
            <th class="w-28 px-3 py-2.5 font-medium">Unit price</th>
            <th class="w-20 px-3 py-2.5 font-medium">Disc %</th>
            <th class="w-40 px-3 py-2.5 font-medium">Tax</th>
            <th :if={@accounts} class="w-48 px-3 py-2.5 font-medium">Account</th>
            <th class="w-28 px-3 py-2.5 text-right font-medium">Amount</th>
            <th class="w-10"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-line">
          <.inputs_for :let={line} field={@form[:lines]}>
            <tr id={"line-#{line.index}"} class="align-top">
              <td class="px-3 py-2">
                <input type="hidden" name={line[:position].name} value={line.index} />
                <.input field={line[:product_id]} type="select" prompt="—" options={@products} />
              </td>
              <td class="px-3 py-2">
                <.input field={line[:description]} placeholder="What you're selling" />
              </td>
              <td class="px-3 py-2">
                <.input field={line[:quantity]} type="number" step="any" min="0" />
              </td>
              <td class="px-3 py-2">
                <.input field={line[:unit_price]} type="number" step="any" min="0" />
              </td>
              <td class="px-3 py-2">
                <.input field={line[:discount_percent]} type="number" step="any" min="0" max="100" />
              </td>
              <td class="px-3 py-2">
                <.input field={line[:tax_rate_id]} type="select" prompt="No tax" options={@tax_rates} />
              </td>
              <td :if={@accounts} class="px-3 py-2">
                <.input
                  field={line[:expense_account_id]}
                  type="select"
                  prompt="Other expenses"
                  options={@accounts}
                />
              </td>
              <td class="tabular px-3 py-4 text-right font-medium text-ink">
                {amount(@preview, line.index, @currency)}
              </td>
              <td class="py-3 pr-2">
                <button
                  type="button"
                  phx-click="remove_line"
                  phx-value-path={line.name}
                  class="rounded p-1 text-muted transition hover:text-danger"
                  aria-label="Remove line"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </td>
            </tr>
          </.inputs_for>
        </tbody>
      </table>
      <div class="flex flex-wrap items-start justify-between gap-6 border-t border-line p-4">
        <.button type="button" phx-click="add_line" id="add-line" size="sm">
          <.icon name="hero-plus-micro" /> Add line
        </.button>
        <.totals totals={@preview.totals} currency={@currency} />
      </div>
    </div>
    """
  end

  defp amount(preview, index, currency) do
    case Map.get(preview, index) do
      nil -> "—"
      line -> Format.money(Money.new!(currency, line.total))
    end
  end

  @doc "Subtotal / tax / total block. Accepts Money values or Decimals plus `currency`."
  attr :totals, :map, required: true
  attr :currency, :string, default: nil
  attr :class, :any, default: nil

  def totals(assigns) do
    ~H"""
    <dl class={["tabular w-64 space-y-1.5 text-sm", @class]}>
      <div class="flex justify-between text-ink-soft">
        <dt>Subtotal</dt>
        <dd>{money(@totals[:subtotal], @currency)}</dd>
      </div>
      <div class="flex justify-between text-ink-soft">
        <dt>Tax</dt>
        <dd>{money(@totals[:tax_amount] || @totals[:tax_total], @currency)}</dd>
      </div>
      <div class="flex justify-between border-t border-line pt-1.5 text-base font-semibold text-ink">
        <dt>Total</dt>
        <dd>{money(@totals[:total], @currency)}</dd>
      </div>
    </dl>
    """
  end

  defp money(%Money{} = money, _currency), do: Format.money(money)
  defp money(%Decimal{} = value, currency), do: Format.money(Money.new!(currency, value))
  defp money(_value, _currency), do: "—"

  @doc "Per-line and total pricing preview from form params (index => amounts, :totals)."
  def preview(params, tax_rates) do
    rates = Map.new(tax_rates, fn rate -> {rate.id, rate.rate} end)

    lines =
      params
      |> Map.get("lines", %{})
      |> normalize_lines()
      |> Enum.with_index()
      |> Map.new(fn {line, index} ->
        {index,
         Pricing.line(
           line["quantity"],
           line["unit_price"],
           line["discount_percent"],
           Map.get(rates, line["tax_rate_id"], 0)
         )}
      end)

    Map.put(lines, :totals, Pricing.totals(Map.values(lines)))
  end

  defp normalize_lines(lines) when is_map(lines) do
    lines |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end) |> Enum.map(&elem(&1, 1))
  rescue
    ArgumentError -> Map.values(lines)
  end

  defp normalize_lines(lines) when is_list(lines), do: lines
  defp normalize_lines(_), do: []

  @doc """
  The document as the customer sees it: on screen and when printed.
  `document` needs `:legal_entity`, the party (`:customer`, or `:supplier` on a
  purchase order, with `:addresses`), `:contact` (sales) and `:lines` loaded.
  """
  attr :document, :map, required: true

  attr :kind, :atom,
    required: true,
    values: [:quote, :invoice, :sales_order, :purchase_order, :rfq]

  def paper(assigns) do
    party = Map.get(assigns.document, :customer) || Map.get(assigns.document, :supplier)

    assigns =
      assign(assigns,
        entity: assigns.document.legal_entity,
        party: party,
        contact: Map.get(assigns.document, :contact),
        address: billing_address(party),
        title:
          %{
            quote: "Quote",
            invoice: "Invoice",
            sales_order: "Order",
            purchase_order: "Purchase order",
            rfq: "Request for quotation"
          }[assigns.kind]
      )

    ~H"""
    <article
      id="document-paper"
      class="mx-auto max-w-[820px] rounded-2xl border border-stone-200 bg-white p-8 text-stone-900 shadow-card sm:p-12 print:max-w-none print:rounded-none print:border-0 print:p-0 print:shadow-none"
    >
      <header class="flex flex-wrap items-start justify-between gap-6">
        <div>
          <p class="text-xl font-bold tracking-tight">{@entity.legal_name || @entity.name}</p>
          <div class="mt-1 text-xs leading-relaxed text-stone-500">
            <p :if={@entity.line1}>{@entity.line1}</p>
            <p :if={@entity.line2}>{@entity.line2}</p>
            <p>{join([@entity.city, @entity.region, @entity.postal_code, @entity.country])}</p>
            <p :if={@entity.email}>{@entity.email}</p>
            <p :if={@entity.phone}>{@entity.phone}</p>
            <p :if={@entity.tax_id}>Tax ID {@entity.tax_id}</p>
          </div>
        </div>
        <div class="text-right">
          <p class="text-3xl font-light tracking-tight text-stone-400 uppercase">{@title}</p>
          <p class="mt-1 font-semibold">{@document.number || "Draft"}</p>
        </div>
      </header>

      <section class="mt-10 grid gap-6 sm:grid-cols-2">
        <div>
          <p class="text-[11px] font-semibold tracking-wider text-stone-400 uppercase">
            {case @kind do
              :invoice -> "Bill to"
              :purchase_order -> "Supplier"
              :rfq -> "Supplier"
              :sales_order -> "Customer"
              _ -> "Prepared for"
            end}
          </p>
          <p class="mt-1 font-semibold">{@party.name}</p>
          <div class="text-sm leading-relaxed text-stone-600">
            <p :if={@contact && @contact.id != @party.id}>
              Attn. {@contact.name}
            </p>
            <p :if={@address}>{@address.line1}</p>
            <p :if={@address && @address.line2}>{@address.line2}</p>
            <p :if={@address}>
              {join([@address.city, @address.region, @address.postal_code, @address.country])}
            </p>
            <p :if={@party.tax_id}>Tax ID {@party.tax_id}</p>
          </div>
        </div>
        <dl class="grid grid-cols-2 gap-y-1 text-sm sm:justify-self-end">
          <dt class="text-stone-500">
            {case @kind do
              kind when kind in [:quote, :invoice] -> "Issued"
              :rfq -> "Requested"
              _order -> "Ordered"
            end}
          </dt>
          <dd class="text-right">{Format.date(@document.issued_on)}</dd>
          <%= case @kind do %>
            <% :invoice -> %>
              <dt class="text-stone-500">Due</dt>
              <dd class="text-right font-semibold">{Format.date(@document.due_on)}</dd>
            <% :quote -> %>
              <dt class="text-stone-500">Valid until</dt>
              <dd class="text-right">{Format.date(@document.valid_until)}</dd>
            <% :rfq -> %>
              <dt class="text-stone-500">Reply by</dt>
              <dd class="text-right">{Format.date(@document.valid_until)}</dd>
            <% _order -> %>
              <dt class="text-stone-500">
                {if @kind == :sales_order, do: "Delivery", else: "Expected"}
              </dt>
              <dd class="text-right">{Format.date(@document.expected_on)}</dd>
          <% end %>
          <dt class="text-stone-500">Currency</dt>
          <dd class="text-right">{@document.currency}</dd>
        </dl>
      </section>

      <table class="mt-10 w-full text-sm">
        <thead>
          <tr class="border-b-2 border-stone-900 text-left text-xs text-stone-500">
            <th class="py-2 font-medium">Description</th>
            <th class="py-2 text-right font-medium">Qty</th>
            <th class="py-2 text-right font-medium">Price</th>
            <th class="py-2 text-right font-medium">Tax</th>
            <th class="py-2 text-right font-medium">Amount</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-stone-200">
          <tr :for={line <- @document.lines} class="align-top">
            <td class="py-3 pr-4">
              {line.description}
              <span :if={Decimal.gt?(line.discount_percent, 0)} class="block text-xs text-stone-500">
                {Decimal.normalize(line.discount_percent)}% discount
              </span>
            </td>
            <td class="tabular py-3 text-right whitespace-nowrap">
              {Decimal.normalize(line.quantity)} {line.unit}
            </td>
            <td class="tabular py-3 text-right">
              {Format.money(Money.new!(@document.currency, line.unit_price))}
            </td>
            <td class="tabular py-3 text-right">{Decimal.normalize(line.tax_percent)}%</td>
            <td class="tabular py-3 text-right font-medium">
              {Format.money(Money.new!(@document.currency, line.subtotal))}
            </td>
          </tr>
        </tbody>
      </table>

      <div class="mt-6 flex justify-end">
        <dl class="tabular w-64 space-y-1.5 text-sm">
          <div class="flex justify-between text-stone-600">
            <dt>Subtotal</dt>
            <dd>{Format.money(@document.subtotal)}</dd>
          </div>
          <div class="flex justify-between text-stone-600">
            <dt>Tax</dt>
            <dd>{Format.money(@document.tax_total)}</dd>
          </div>
          <div class="flex justify-between border-t-2 border-stone-900 pt-2 text-base font-semibold">
            <dt>Total</dt>
            <dd>{Format.money(@document.total)}</dd>
          </div>
          <%= if @kind == :invoice and @document.amount_paid && Money.positive?(@document.amount_paid) do %>
            <div class="flex justify-between text-stone-600">
              <dt>Paid</dt>
              <dd>−{Format.money(@document.amount_paid)}</dd>
            </div>
            <div class="flex justify-between font-semibold">
              <dt>Amount due</dt>
              <dd>{Format.money(Money.sub!(@document.total, @document.amount_paid))}</dd>
            </div>
          <% end %>
        </dl>
      </div>

      <section :if={@document.notes} class="mt-10 text-sm whitespace-pre-line text-stone-600">
        {@document.notes}
      </section>

      <footer
        :if={@kind == :invoice and @entity.invoice_footer}
        class="mt-12 border-t border-stone-200 pt-4 text-xs whitespace-pre-line text-stone-500"
      >
        {@entity.invoice_footer}
      </footer>
    </article>
    """
  end

  defp billing_address(%{addresses: addresses}) when is_list(addresses) do
    Enum.find(addresses, &(&1.kind == :billing)) || List.first(addresses)
  end

  defp billing_address(_), do: nil

  defp join(parts), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(", ")
end
