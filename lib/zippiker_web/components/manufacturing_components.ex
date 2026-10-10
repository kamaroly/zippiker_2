defmodule ZippikerWeb.ManufacturingComponents do
  @moduledoc "Production order badges, progress and the printable job card."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents

  alias ZippikerWeb.Format

  attr :status, :atom, required: true

  def production_status(assigns) do
    ~H"""
    <.badge color={
      %{
        draft: :slate,
        confirmed: :blue,
        in_progress: :amber,
        done: :emerald,
        cancelled: :slate
      }[@status]
    }>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  attr :order, :map, required: true
  attr :class, :any, default: nil

  def production_progress(assigns) do
    assigns =
      assign(assigns,
        percent:
          if(Decimal.gt?(assigns.order.quantity, 0),
            do:
              min(
                100,
                round(
                  Decimal.to_float(assigns.order.produced_quantity) /
                    Decimal.to_float(assigns.order.quantity) * 100
                )
              ),
            else: 0
          )
      )

    ~H"""
    <div class={["flex items-center gap-2", @class]}>
      <div class="h-1.5 min-w-16 flex-1 overflow-hidden rounded-full bg-canvas ring-1 ring-line">
        <div class="h-full rounded-full bg-success transition-all" style={"width: #{@percent}%"} />
      </div>
      <span class="tabular text-xs text-muted">
        {qty(@order.produced_quantity)}/{qty(@order.quantity)}
      </span>
    </div>
    """
  end

  @doc "A quantity without trailing zeros."
  def qty(nil), do: "0"
  def qty(%Decimal{} = value), do: value |> Decimal.normalize() |> Decimal.to_string(:normal)

  @doc "Minutes as `1 h 30 min`."
  def duration(%Decimal{} = minutes) do
    total = minutes |> Decimal.round(0) |> Decimal.to_integer()

    case {div(total, 60), rem(total, 60)} do
      {0, m} -> "#{m} min"
      {h, 0} -> "#{h} h"
      {h, m} -> "#{h} h #{m} min"
    end
  end

  @doc "The shop-floor job card for a production order: what to make, pick and do."
  attr :order, :map, required: true
  attr :requirements, :list, required: true
  attr :operations, :list, required: true

  def job_card(assigns) do
    ~H"""
    <article
      id="job-card"
      class="mx-auto max-w-[820px] rounded-2xl border border-stone-200 bg-white p-8 text-stone-900 shadow-card sm:p-12 print:max-w-none print:rounded-none print:border-0 print:p-0 print:shadow-none"
    >
      <header class="flex flex-wrap items-start justify-between gap-6">
        <div>
          <p class="text-xl font-bold tracking-tight">
            {@order.legal_entity.legal_name || @order.legal_entity.name}
          </p>
          <p class="mt-1 text-xs text-stone-500">
            {(@order.warehouse && @order.warehouse.name) || "Default warehouse"}
          </p>
        </div>
        <div class="text-right">
          <p class="text-2xl font-light tracking-tight text-stone-400 uppercase">Job card</p>
          <p class="mt-1 font-semibold">{@order.number}</p>
        </div>
      </header>

      <section class="mt-8 grid gap-6 rounded-xl bg-stone-50 p-5 sm:grid-cols-[1fr_auto] print:bg-white print:ring-1 print:ring-stone-300">
        <div>
          <p class="text-[11px] font-semibold tracking-wider text-stone-400 uppercase">Make</p>
          <p class="mt-1 text-2xl font-semibold">
            {qty(@order.quantity)} × {@order.product.name}
          </p>
          <p :if={@order.product.sku} class="text-sm text-stone-500">SKU {@order.product.sku}</p>
        </div>
        <dl class="grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
          <dt class="text-stone-500">Start</dt>
          <dd class="text-right">{Format.date(@order.planned_start)}</dd>
          <dt class="text-stone-500">Due</dt>
          <dd class="text-right">{Format.date(@order.due_on)}</dd>
          <dt class="text-stone-500">Recipe</dt>
          <dd class="text-right">{@order.bom.reference}</dd>
          <dt class="text-stone-500">Already made</dt>
          <dd class="text-right">{qty(@order.produced_quantity)}</dd>
        </dl>
      </section>

      <h3 class="mt-10 text-xs font-semibold tracking-wider text-stone-500 uppercase">
        Components to pick
      </h3>
      <table class="mt-2 w-full text-sm">
        <thead>
          <tr class="border-b-2 border-stone-900 text-left text-xs text-stone-500">
            <th class="w-8 py-2 font-medium">#</th>
            <th class="py-2 font-medium">Component</th>
            <th class="py-2 font-medium">SKU</th>
            <th class="py-2 text-right font-medium">Quantity</th>
            <th class="w-20 py-2 text-right font-medium">Picked</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-stone-200">
          <tr :for={{row, index} <- Enum.with_index(@requirements, 1)}>
            <td class="py-3 text-stone-400">{index}</td>
            <td class="py-3 font-medium">{row.product.name}</td>
            <td class="py-3 text-stone-500">{row.product.sku}</td>
            <td class="py-3 text-right tabular-nums">{qty(row.required)} {row.product.unit}</td>
            <td class="py-3 text-right">
              <span class="inline-block size-4 rounded border border-stone-400" />
            </td>
          </tr>
        </tbody>
      </table>

      <%= if @operations != [] do %>
        <h3 class="mt-10 text-xs font-semibold tracking-wider text-stone-500 uppercase">
          Operations
        </h3>
        <table class="mt-2 w-full text-sm">
          <thead>
            <tr class="border-b-2 border-stone-900 text-left text-xs text-stone-500">
              <th class="w-8 py-2 font-medium">#</th>
              <th class="py-2 font-medium">Operation</th>
              <th class="py-2 font-medium">Work center</th>
              <th class="py-2 text-right font-medium">Planned time</th>
              <th class="w-24 py-2 text-right font-medium">Done by</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-stone-200">
            <tr :for={{row, index} <- Enum.with_index(@operations, 1)}>
              <td class="py-3 align-top text-stone-400">{index}</td>
              <td class="py-3">
                <span class="font-medium">{row.operation.name}</span>
                <span :if={row.operation.instructions} class="block text-xs text-stone-500">
                  {row.operation.instructions}
                </span>
              </td>
              <td class="py-3 align-top">{row.operation.work_center.name}</td>
              <td class="py-3 text-right align-top tabular-nums">{duration(row.minutes)}</td>
              <td class="py-3 align-top"><span class="block border-b border-stone-300 pt-4" /></td>
            </tr>
          </tbody>
        </table>
      <% end %>

      <p :if={@order.notes} class="mt-8 text-sm whitespace-pre-line text-stone-600">
        {@order.notes}
      </p>

      <footer class="mt-14 grid grid-cols-3 gap-8 text-xs text-stone-500">
        <div class="border-t border-stone-400 pt-2">Produced quantity</div>
        <div class="border-t border-stone-400 pt-2">Checked by</div>
        <div class="border-t border-stone-400 pt-2">Date</div>
      </footer>
    </article>
    """
  end
end
