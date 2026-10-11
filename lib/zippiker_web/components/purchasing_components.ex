defmodule ZippikerWeb.PurchasingComponents do
  @moduledoc "Purchasing and inventory badges."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents
  import ZippikerWeb.DocumentComponents

  alias ZippikerWeb.Format

  attr :status, :atom, required: true

  def purchase_order_status(assigns) do
    ~H"""
    <.badge color={
      %{
        draft: :slate,
        ordered: :blue,
        partially_received: :amber,
        received: :emerald,
        cancelled: :rose
      }[@status]
    }>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  attr :status, :atom, required: true

  def rfq_status(assigns) do
    ~H"""
    <.badge color={
      %{draft: :slate, sent: :blue, quoted: :violet, accepted: :emerald, declined: :rose}[@status]
    }>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  @doc "Bill badge; open bills show Overdue or Partially paid when relevant."
  attr :bill, :map, required: true

  def bill_status(assigns) do
    {label, color} =
      case assigns.bill do
        %{status: :open} = bill ->
          cond do
            Map.get(bill, :overdue?) == true -> {"Overdue", :rose}
            bill.amount_paid && Money.positive?(bill.amount_paid) -> {"Partially paid", :amber}
            true -> {"To pay", :blue}
          end

        %{status: :draft} ->
          {"Draft", :slate}

        %{status: :paid} ->
          {"Paid", :emerald}

        %{status: :void} ->
          {"Void", :slate}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end

  attr :operation, :map, required: true

  def operation_kind(assigns) do
    {label, color} =
      case assigns.operation do
        %{reversal_of_id: id} when not is_nil(id) -> {"Reversal", :slate}
        %{kind: :receipt} -> {"Receipt", :emerald}
        %{kind: :delivery} -> {"Delivery", :orange}
        %{kind: :adjustment} -> {"Adjustment", :violet}
        %{kind: :production} -> {"Production", :teal}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end

  @doc "Signed quantity: +12 in green, −3 in the danger color."
  attr :quantity, :any, required: true
  attr :unit, :string, default: nil

  def signed_quantity(assigns) do
    ~H"""
    <span class={[
      "tabular font-medium",
      Decimal.gt?(@quantity, 0) && "text-success",
      Decimal.lt?(@quantity, 0) && "text-danger"
    ]}>
      {if Decimal.gt?(@quantity, 0), do: "+"}{Decimal.normalize(@quantity)} {@unit}
    </span>
    """
  end

  @doc """
  A printable note (goods received note, delivery note, stock slip): issuer,
  the other party, key facts, the items with quantities (no prices), a tick
  box per line and signature lines.
  """
  attr :id, :string, default: "note-paper"
  attr :kind, :atom, required: true, doc: ":goods_receipt, :delivery_note or :stock_note"
  attr :title, :string, default: nil
  attr :number, :string, required: true
  attr :entity, :map, required: true, doc: "the legal entity issuing it"
  attr :party, :map, default: nil, doc: "supplier or customer, with :addresses loaded"
  attr :party_label, :string, default: nil
  attr :facts, :list, default: [], doc: "{label, value} rows; nil values are skipped"
  attr :lines, :list, required: true, doc: "maps with :description, :sku, :quantity, :unit"
  attr :memo, :string, default: nil
  attr :signatures, :list, required: true

  def note_paper(assigns) do
    assigns =
      assign(assigns,
        address: assigns.party && shipping_address(assigns.party),
        facts: Enum.reject(assigns.facts, fn {_label, value} -> value in [nil, ""] end)
      )

    ~H"""
    <.document_sheet id={@id} entity={@entity}>
      <.letterhead entity={@entity} kind={@kind} number={@number} title={@title} />

      <section class="mt-8 grid gap-6 sm:grid-cols-2">
        <div :if={@party}>
          <p class="text-[11px] font-semibold tracking-wider text-stone-400 uppercase">
            {@party_label}
          </p>
          <p class="mt-1 font-semibold">{@party.name}</p>
          <div :if={@address} class="text-sm leading-relaxed text-stone-600">
            <p>{@address.line1}</p>
            <p :if={@address.line2}>{@address.line2}</p>
            <p>{join([@address.city, @address.region, @address.postal_code, @address.country])}</p>
          </div>
          <p :if={@party.phone} class="text-sm text-stone-600">{@party.phone}</p>
        </div>
        <dl class="grid grid-cols-2 gap-x-6 gap-y-1 text-sm sm:col-start-2 sm:justify-self-end">
          <%= for {label, value} <- @facts do %>
            <dt class="text-stone-500">{label}</dt>
            <dd class="text-right">{value}</dd>
          <% end %>
        </dl>
      </section>

      <table class="mt-10 w-full text-sm">
        <thead>
          <tr class="border-b-2 border-(--doc-accent) text-left text-xs text-stone-500">
            <th class="w-8 py-2 font-medium">#</th>
            <th class="py-2 font-medium">Item</th>
            <th class="py-2 font-medium">SKU</th>
            <th class="py-2 text-right font-medium">Quantity</th>
            <th class="w-20 py-2 text-right font-medium">Checked</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-stone-200">
          <tr :for={{line, index} <- Enum.with_index(@lines, 1)}>
            <td class="py-3 text-stone-400">{index}</td>
            <td class="py-3 pr-4">{line.description}</td>
            <td class="py-3 font-mono text-xs text-stone-500">{line.sku}</td>
            <td class="tabular py-3 text-right font-medium whitespace-nowrap">
              {line.quantity |> Decimal.abs() |> Decimal.normalize()} {line.unit}
            </td>
            <td class="py-3 text-right">
              <span class="inline-block size-4 rounded border border-stone-400" />
            </td>
          </tr>
        </tbody>
      </table>

      <section :if={@memo} class="mt-8 text-sm whitespace-pre-line text-stone-600">{@memo}</section>

      <.document_footer entity={@entity} kind={@kind} />

      <footer
        :if={signatures?(@entity)}
        class="mt-16 grid gap-10 text-xs text-stone-500 sm:grid-cols-2"
      >
        <div :for={label <- @signatures}>
          <div class="h-10 border-b border-stone-400" />
          <p class="mt-1">{label}</p>
        </div>
      </footer>
    </.document_sheet>
    """
  end

  @doc "A goods received note (`lines: [:product]`, `:legal_entity`, `:warehouse`, `supplier: [:addresses]`, `:purchase_order`)."
  attr :note, :map, required: true
  attr :id, :string, default: "grn-paper"

  def goods_receipt_paper(assigns) do
    ~H"""
    <.note_paper
      id={@id}
      kind={:goods_receipt}
      number={@note.number}
      entity={@note.legal_entity}
      party={@note.supplier}
      party_label="Received from"
      facts={[
        {"Received", Format.date(@note.received_on)},
        {"Warehouse", @note.warehouse && @note.warehouse.name},
        {"Our order", @note.purchase_order && @note.purchase_order.number},
        {"Supplier ref.", @note.supplier_reference}
      ]}
      lines={Enum.map(@note.lines, &note_line/1)}
      memo={@note.notes}
      signatures={["Received by (name, signature)", "Checked by (name, signature, date)"]}
    />
    """
  end

  @doc "A delivery note (`lines: [:product]`, `:legal_entity`, `:warehouse`, `customer: [:addresses]`, `:sales_order`, `:invoice`)."
  attr :note, :map, required: true
  attr :id, :string, default: "dn-paper"

  def delivery_paper(assigns) do
    ~H"""
    <.note_paper
      id={@id}
      kind={:delivery_note}
      number={@note.number}
      entity={@note.legal_entity}
      party={@note.customer}
      party_label="Deliver to"
      facts={[
        {"Shipped", Format.date(@note.shipped_on)},
        {"From", @note.warehouse && @note.warehouse.name},
        {"Order", @note.sales_order && @note.sales_order.number},
        {"Invoice", @note.invoice && @note.invoice.number},
        {"Carrier", @note.carrier},
        {"Tracking", @note.tracking_number}
      ]}
      lines={Enum.map(@note.lines, &note_line/1)}
      memo={@note.notes}
      signatures={[
        "Delivered by (name, signature)",
        "Received in good condition by (name, signature, date)"
      ]}
    />
    """
  end

  defp note_line(line) do
    %{
      description: line.description,
      sku: line.product && line.product.sku,
      quantity: line.quantity,
      unit: line.unit
    }
  end

  attr :status, :atom, required: true

  def delivery_status(assigns) do
    ~H"""
    <.badge color={%{shipped: :blue, delivered: :emerald, cancelled: :slate}[@status]}>
      {%{shipped: "In transit", delivered: "Delivered", cancelled: "Cancelled"}[@status]}
    </.badge>
    """
  end

  @doc "Adjustment slip for a stock operation (`movements: [:product]`, `:legal_entity`, `:warehouse`, `party`)."
  attr :operation, :map, required: true

  def stock_note(assigns) do
    ~H"""
    <.note_paper
      id="stock-note"
      kind={:stock_note}
      title={if(@operation.kind == :adjustment, do: "Stock adjustment", else: "Stock movement")}
      number={@operation.number}
      entity={@operation.legal_entity}
      party={@operation.party}
      party_label={if(@operation.kind == :receipt, do: "From", else: "To")}
      facts={[
        {"Date", Format.date(@operation.date)},
        {"Warehouse", @operation.warehouse.name},
        {"Document", @operation.source_label},
        {"Reference", @operation.reference}
      ]}
      lines={
        Enum.map(@operation.movements, fn movement ->
          %{
            description: movement.product.name,
            sku: movement.product.sku,
            quantity: movement.quantity,
            unit: movement.product.unit
          }
        end)
      }
      memo={@operation.memo}
      signatures={["Counted by (name, signature)", "Approved by (name, signature, date)"]}
    />
    """
  end

  defp shipping_address(%{addresses: addresses}) when is_list(addresses) do
    Enum.find(addresses, &(&1.kind == :shipping)) || List.first(addresses)
  end

  defp shipping_address(_party), do: nil

  defp join(parts), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(", ")
end
