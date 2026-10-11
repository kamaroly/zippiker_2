defmodule ZippikerWeb.DocumentComponents do
  @moduledoc """
  The look of printed documents, from the issuing legal entity's
  `document_style` (layout, accent colour, font, logo) and per-type
  templates (title, terms, footer). Every document (quotes, orders,
  invoices, RFQs, LPOs, GRNs, delivery notes, stock notes, job cards) uses
  `document_sheet/1` and `letterhead/1`.
  """
  use Phoenix.Component

  alias Zippiker.Accounts.DocumentStyle

  @default_titles %{
    quote: "Quote",
    sales_order: "Order",
    invoice: "Invoice",
    delivery_note: "Delivery note",
    rfq: "Request for quotation",
    purchase_order: "Purchase order",
    goods_receipt: "Goods received note",
    stock_note: "Stock movement",
    job_card: "Job card"
  }

  @labels %{
    quote: "Quotes",
    sales_order: "Sales orders",
    invoice: "Invoices",
    delivery_note: "Delivery notes",
    rfq: "Requests for quotation",
    purchase_order: "Purchase orders (LPOs)",
    goods_receipt: "Goods received notes (GRNs)",
    stock_note: "Stock movements",
    job_card: "Job cards"
  }

  def default_document_title(kind), do: @default_titles[kind]
  def document_kind_label(kind), do: @labels[kind]

  @doc "The entity's style with defaults filled in."
  def style(%{document_style: %DocumentStyle{} = style}), do: style

  def style(_entity),
    do:
      struct(
        DocumentStyle,
        Map.new(Ash.Resource.Info.attributes(DocumentStyle), &{&1.name, &1.default})
      )

  @doc "Title, terms and footer for a document type (blank ones use the defaults)."
  def template(entity, kind) do
    found = Enum.find(style(entity).templates || [], &(&1.kind == kind))

    %{
      title: present(found && found.title) || @default_titles[kind],
      terms: present(found && found.terms),
      footer:
        present(found && found.footer) ||
          if(kind == :invoice, do: present(Map.get(entity, :invoice_footer)))
    }
  end

  defp present(value) when value in [nil, ""], do: nil
  defp present(value), do: value

  @doc "The sheet of paper: width, padding, font and the accent colour variable."
  attr :id, :string, required: true
  attr :entity, :map, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def document_sheet(assigns) do
    assigns = assign(assigns, :style, style(assigns.entity))

    ~H"""
    <article
      id={@id}
      style={"--doc-accent: #{@style.accent_color}"}
      class={[
        "mx-auto max-w-[820px] overflow-hidden rounded-2xl border border-stone-200 bg-white text-stone-900 shadow-card",
        "print:max-w-none print:rounded-none print:border-0 print:shadow-none",
        font_class(@style.font),
        @style.layout == :compact && "p-6 text-[13px] sm:p-8 print:p-0",
        @style.layout != :compact && "p-8 sm:p-12 print:p-0"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </article>
    """
  end

  defp font_class(:serif), do: "font-serif"
  defp font_class(:mono), do: "font-mono"
  defp font_class(_sans), do: "font-sans"

  @doc """
  The top of a document: logo, issuer details and the title with the
  document number, laid out by the style.
  """
  attr :entity, :map, required: true
  attr :kind, :atom, required: true
  attr :number, :string, default: nil
  attr :title, :string, default: nil, doc: "used when the workspace hasn't set its own title"
  attr :details, :boolean, default: true, doc: "show the issuer's address and contacts"

  def letterhead(assigns) do
    style = style(assigns.entity)

    custom =
      Enum.find_value(style.templates || [], fn template ->
        template.kind == assigns.kind && present(template.title)
      end)

    assigns =
      assign(assigns,
        style: style,
        title: custom || assigns.title || @default_titles[assigns.kind],
        logo: logo_url(assigns.entity)
      )

    ~H"""
    <%= if @style.layout == :modern do %>
      <header
        class="-mx-8 -mt-8 mb-2 bg-(--doc-accent) px-8 py-7 text-white sm:-mx-12 sm:-mt-12 sm:px-12 print:mx-0 print:mt-0 print:px-6"
        style="-webkit-print-color-adjust: exact; print-color-adjust: exact;"
      >
        <div class="flex flex-wrap items-center justify-between gap-6">
          <div class="flex items-center gap-4">
            <span :if={@logo} class="rounded-lg bg-white p-1.5">
              <img src={@logo} alt="" class={logo_class(@style.logo_size)} />
            </span>
            <div>
              <p class="text-xl font-bold tracking-tight">{@entity.legal_name || @entity.name}</p>
              <p :if={@details} class="text-xs text-white/80">
                {join([@entity.line1, @entity.city, @entity.country])}
              </p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-2xl font-semibold tracking-tight uppercase">{@title}</p>
            <p class="mt-0.5 font-medium text-white/90">{@number || "Draft"}</p>
          </div>
        </div>
      </header>
      <.issuer_details :if={@details} entity={@entity} style={@style} class="mt-4 text-right" />
    <% else %>
      <header class={[
        "flex flex-wrap items-start justify-between gap-6",
        @style.layout == :compact && "border-b-2 border-(--doc-accent) pb-4"
      ]}>
        <div class="flex items-start gap-4">
          <img :if={@logo} src={@logo} alt="" class={logo_class(@style.logo_size)} />
          <div>
            <p class="text-xl font-bold tracking-tight">{@entity.legal_name || @entity.name}</p>
            <.issuer_details :if={@details} entity={@entity} style={@style} class="mt-1" />
          </div>
        </div>
        <div class="text-right">
          <p class={[
            "font-light tracking-tight uppercase text-(--doc-accent)",
            @style.layout == :compact && "text-2xl",
            @style.layout != :compact && "text-3xl"
          ]}>
            {@title}
          </p>
          <p class="mt-1 font-semibold">{@number || "Draft"}</p>
        </div>
      </header>
    <% end %>
    """
  end

  attr :entity, :map, required: true
  attr :style, :map, required: true
  attr :class, :any, default: nil

  defp issuer_details(assigns) do
    ~H"""
    <div class={["text-xs leading-relaxed text-stone-500", @class]}>
      <p :if={@entity.line1}>{@entity.line1}</p>
      <p :if={@entity.line2}>{@entity.line2}</p>
      <p>{join([@entity.city, @entity.region, @entity.postal_code, @entity.country])}</p>
      <p>{join([@entity.email && to_string(@entity.email), @entity.phone])}</p>
      <p :if={@style.show_tax_ids? and @entity.tax_id}>Tax ID {@entity.tax_id}</p>
    </div>
    """
  end

  defp logo_class(:small), do: "h-10 w-auto max-w-32 object-contain"
  defp logo_class(:large), do: "h-20 w-auto max-w-56 object-contain"
  defp logo_class(_medium), do: "h-14 w-auto max-w-44 object-contain"

  @doc "Terms and footer of a document type, if set."
  attr :entity, :map, required: true
  attr :kind, :atom, required: true

  def document_footer(assigns) do
    assigns = assign(assigns, :template, template(assigns.entity, assigns.kind))

    ~H"""
    <section
      :if={@template.terms}
      class="mt-8 border-l-2 border-(--doc-accent) pl-4 text-xs leading-relaxed whitespace-pre-line text-stone-600"
    >
      <p class="mb-1 font-semibold tracking-wider text-stone-400 uppercase">Terms</p>
      {@template.terms}
    </section>
    <footer
      :if={@template.footer}
      class="mt-10 border-t border-stone-200 pt-4 text-xs whitespace-pre-line text-stone-500"
    >
      {@template.footer}
    </footer>
    """
  end

  @doc "Whether signature lines are printed."
  def signatures?(entity), do: style(entity).show_signatures?

  @doc "Whether tax IDs are printed."
  def tax_ids?(entity), do: style(entity).show_tax_ids?

  @doc "URL of the entity's logo, or nil."
  # Logos are stored as "<organization id>/logos/<file>".
  def logo_url(%{logo_path: path, id: id}) when is_binary(path) do
    [organization_id | _] = String.split(path, "/")
    version = path |> :erlang.phash2() |> Integer.to_string(36)
    "/logos/#{organization_id}/#{id}?v=#{version}"
  end

  def logo_url(_entity), do: nil

  defp join(parts), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(", ")
end
