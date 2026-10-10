defmodule ZippikerWeb.AccountingComponents do
  @moduledoc "Accounting presentation components: badges, the income/expense chart, statements."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents

  @type_labels %{
    asset: {"Asset", :blue},
    liability: {"Liability", :amber},
    equity: {"Equity", :violet},
    income: {"Income", :emerald},
    expense: {"Expense", :rose}
  }

  @doc "Account type pill."
  attr :type, :atom, required: true

  def account_type(assigns) do
    {label, color} = @type_labels[assigns.type]
    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end

  @doc "Where a journal entry came from."
  attr :entry, :map, required: true

  def entry_source(assigns) do
    {label, color} =
      case assigns.entry do
        %{reversal_of_id: id} when not is_nil(id) -> {"Reversal", :slate}
        %{source: :invoice} -> {"Invoice", :orange}
        %{source: :payment} -> {"Payment", :emerald}
        %{source: :expense} -> {"Expense", :rose}
        _ -> {"Manual", :blue}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end

  @doc "Paired monthly bars: income (brand) and expenses (muted)."
  attr :trend, :list, required: true, doc: "[%{month, income, expenses}]"
  attr :currency, :string, required: true

  def income_expense_chart(assigns) do
    max =
      assigns.trend
      |> Enum.flat_map(&[Decimal.to_float(&1.income), Decimal.to_float(&1.expenses)])
      |> Enum.max(fn -> 0 end)

    assigns = assign(assigns, max: max)

    ~H"""
    <div class="flex h-48 items-end gap-3 sm:gap-6">
      <div
        :for={point <- @trend}
        class="group flex h-full flex-1 flex-col items-center justify-end gap-2"
        title={"Income #{ZippikerWeb.LiveHelpers.amount(point.income, @currency)} · Expenses #{ZippikerWeb.LiveHelpers.amount(point.expenses, @currency)}"}
      >
        <div class="flex h-full w-full items-end justify-center gap-1">
          <div
            class="w-full max-w-5 rounded-t-md bg-brand transition-all duration-300 group-hover:opacity-80"
            style={"height: #{height(point.income, @max)}%"}
          />
          <div
            class="w-full max-w-5 rounded-t-md bg-line-strong transition-all duration-300 group-hover:opacity-80"
            style={"height: #{height(point.expenses, @max)}%"}
          />
        </div>
        <span class="text-xs text-muted">{Calendar.strftime(point.month, "%b")}</span>
      </div>
    </div>
    <div class="mt-3 flex gap-4 text-xs text-muted">
      <span class="flex items-center gap-1.5"><span class="size-2 rounded-full bg-brand" /> Income</span>
      <span class="flex items-center gap-1.5">
        <span class="size-2 rounded-full bg-line-strong" /> Expenses
      </span>
    </div>
    """
  end

  defp height(_value, max) when max == 0, do: 1
  defp height(value, max), do: max(1, round(Decimal.to_float(value) / max * 100))

  @doc "A titled block of `%{account, amount}` rows with a total, for statements."
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :total_label, :string, required: true
  attr :total, :any, required: true
  attr :currency, :string, required: true
  slot :extra, doc: "rows rendered after the accounts (e.g. current earnings)"

  def statement_section(assigns) do
    ~H"""
    <section id={@id} class="py-2">
      <h3 class="px-5 pt-3 pb-1 text-xs font-semibold tracking-wider text-muted uppercase">
        {@title}
      </h3>
      <.link
        :for={row <- @rows}
        navigate={"/accounting/accounts/#{row.account.id}"}
        class="flex items-center justify-between gap-4 px-5 py-1.5 text-sm transition hover:bg-canvas"
      >
        <span class="text-ink-soft">
          <span class="tabular mr-2 text-xs text-muted">{row.account.code}</span>{row.account.name}
        </span>
        <span class="tabular text-ink">{ZippikerWeb.LiveHelpers.amount(row.amount, @currency)}</span>
      </.link>
      {render_slot(@extra)}
      <p :if={@rows == [] and @extra == []} class="px-5 py-1.5 text-sm text-muted">Nothing yet.</p>
      <div class="mx-5 mt-1 flex items-center justify-between border-t border-line pt-2 text-sm font-semibold text-ink">
        <span>{@total_label}</span>
        <span class="tabular">{ZippikerWeb.LiveHelpers.amount(@total, @currency)}</span>
      </div>
    </section>
    """
  end
end
