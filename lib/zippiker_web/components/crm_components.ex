defmodule ZippikerWeb.CrmComponents do
  @moduledoc "CRM-specific presentation components."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents

  alias ZippikerWeb.Format

  @doc "KPI tile."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, doc: "secondary line"

  def stat(assigns) do
    ~H"""
    <div id={@id} class="rounded-2xl border border-line bg-surface p-5 shadow-card">
      <div class="flex items-center justify-between">
        <p class="text-xs font-medium text-muted">{@label}</p>
        <span class="flex size-7 items-center justify-center rounded-lg bg-canvas text-ink-soft">
          <.icon name={@icon} class="size-4" />
        </span>
      </div>
      <p class="tabular mt-2 text-2xl font-semibold tracking-tight text-ink">{@value}</p>
      <p :if={@inner_block != []} class="mt-1 text-xs text-muted">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  @doc "Colored stage pill."
  attr :stage, :map, required: true

  def stage_badge(assigns) do
    ~H"""
    <.badge color={@stage.color}>
      <span class={["size-1.5 rounded-full", dot_color(@stage.color)]} />
      {@stage.name}
    </.badge>
    """
  end

  @lead_status_colors %{
    new: :blue,
    contacted: :amber,
    qualified: :emerald,
    disqualified: :slate,
    converted: :orange
  }

  attr :status, :atom, required: true

  def lead_status(assigns) do
    assigns = assign(assigns, :color, @lead_status_colors[assigns.status])

    ~H"""
    <.badge color={@color}>{Format.humanize(@status)}</.badge>
    """
  end

  attr :status, :atom, required: true

  def deal_status(assigns) do
    ~H"""
    <.badge color={%{open: :blue, won: :emerald, lost: :rose}[@status]}>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  @doc "Role chips for a party (customer, supplier, ...)."
  attr :roles, :list, required: true

  def roles(assigns) do
    ~H"""
    <span class="inline-flex flex-wrap gap-1">
      <.badge :for={role <- @roles} color={if(role == :customer, do: :emerald, else: :slate)}>
        {Format.humanize(role)}
      </.badge>
    </span>
    """
  end

  @doc """
  Inputs for an entity's custom field definitions, submitted as
  `form[custom_fields][key]`. Every field always submits a value so the
  server can tell "cleared" from "not on this form".
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :definitions, :list, required: true

  def custom_field_inputs(assigns) do
    values = AshPhoenix.Form.value(assigns.form.source, :custom_fields) || %{}
    errors = for {:custom_fields, {message, _}} <- assigns.form.errors, do: message

    assigns =
      assign(assigns,
        values: values,
        errors:
          if(Phoenix.Component.used_input?(assigns.form[:custom_fields]), do: errors, else: []),
        base: assigns.form[:custom_fields].name
      )

    ~H"""
    <div :if={@definitions != []} class="space-y-4 border-t border-line pt-5">
      <p class="text-xs font-semibold tracking-wider text-muted uppercase">Custom fields</p>
      <div class="grid gap-4 sm:grid-cols-2">
        <div
          :for={definition <- @definitions}
          class={definition.type in [:long_text, :multi_select] && "sm:col-span-2"}
        >
          <.custom_field_input
            definition={definition}
            name={"#{@base}[#{definition.key}]"}
            id={"#{@form.id}_cf_#{definition.key}"}
            value={Map.get(@values, definition.key)}
          />
        </div>
      </div>
      <.error :for={message <- @errors}>{message}</.error>
    </div>
    """
  end

  attr :definition, :map, required: true
  attr :name, :string, required: true
  attr :id, :string, required: true
  attr :value, :any

  defp custom_field_input(%{definition: %{type: :multi_select}} = assigns) do
    ~H"""
    <fieldset>
      <.label>{field_label(@definition)}</.label>
      <input type="hidden" name={"#{@name}[]"} value="" />
      <div class="flex flex-wrap gap-2">
        <label
          :for={option <- @definition.options}
          class="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-line px-3 py-1.5 text-sm text-ink transition has-[:checked]:border-brand has-[:checked]:bg-brand-soft"
        >
          <input
            type="checkbox"
            name={"#{@name}[]"}
            value={option}
            checked={option in List.wrap(@value)}
            class="accent-brand"
          />
          {option}
        </label>
      </div>
      <p :if={@definition.help_text} class="mt-1 text-xs text-muted">{@definition.help_text}</p>
    </fieldset>
    """
  end

  defp custom_field_input(%{definition: %{type: :boolean}} = assigns) do
    ~H"""
    <div class="pt-6">
      <.input type="checkbox" id={@id} name={@name} value={@value} label={field_label(@definition)} />
    </div>
    """
  end

  defp custom_field_input(%{definition: %{type: :select}} = assigns) do
    ~H"""
    <.input
      type="select"
      id={@id}
      name={@name}
      value={@value}
      label={field_label(@definition)}
      prompt="—"
      options={@definition.options}
      hint={@definition.help_text}
    />
    """
  end

  defp custom_field_input(assigns) do
    assigns =
      assign(assigns,
        type:
          %{long_text: "textarea", number: "number", date: "date", url: "url", email: "email"}[
            assigns.definition.type
          ] || "text"
      )

    ~H"""
    <.input
      type={@type}
      id={@id}
      name={@name}
      value={@value}
      label={field_label(@definition)}
      hint={@definition.help_text}
      step={@type == "number" && "any"}
    />
    """
  end

  defp field_label(%{label: label, required?: true}), do: label <> " *"
  defp field_label(%{label: label}), do: label

  @doc "Read-only list of custom field values."
  attr :values, :map, required: true
  attr :definitions, :list, required: true

  def custom_field_values(assigns) do
    ~H"""
    <.list :if={@definitions != []}>
      <:item :for={definition <- @definitions} title={definition.label}>
        {custom_value(definition, Map.get(@values || %{}, definition.key))}
      </:item>
    </.list>
    """
  end

  defp custom_value(_definition, nil), do: "—"
  defp custom_value(%{type: :boolean}, value), do: if(value, do: "Yes", else: "No")
  defp custom_value(%{type: :multi_select}, values), do: Enum.join(values, ", ")
  defp custom_value(%{type: :date}, value), do: value |> Date.from_iso8601!() |> Format.date()
  defp custom_value(_definition, value), do: to_string(value)

  @doc """
  Six-month revenue bar chart, drawn with plain HTML so it costs nothing to
  ship and scales with the container.
  """
  attr :trend, :list, required: true

  def revenue_chart(assigns) do
    max =
      assigns.trend
      |> Enum.map(&Decimal.to_float(&1.amount.amount))
      |> Enum.max(fn -> 0 end)

    assigns = assign(assigns, max: max)

    ~H"""
    <div class="flex h-48 items-end gap-3 sm:gap-5">
      <div
        :for={%{month: month, amount: amount} <- @trend}
        class="group flex h-full flex-1 flex-col items-center justify-end gap-2"
      >
        <span class="tabular text-[11px] font-medium text-muted opacity-0 transition-opacity group-hover:opacity-100">
          {Format.money_short(amount)}
        </span>
        <div
          class={[
            "w-full max-w-12 rounded-t-md transition-all duration-300",
            month == List.last(@trend).month && "bg-brand",
            month != List.last(@trend).month && "bg-brand/25 group-hover:bg-brand/45"
          ]}
          style={"height: #{bar_height(amount, @max)}%"}
        />
        <span class="text-xs text-muted">{Calendar.strftime(month, "%b")}</span>
      </div>
    </div>
    """
  end

  defp bar_height(_amount, max) when max == 0, do: 2

  defp bar_height(amount, max),
    do: max(2, round(Decimal.to_float(amount.amount) / max * 100))

  @doc "Horizontal bars of open pipeline value per stage."
  attr :stages, :list, required: true

  def pipeline_bars(assigns) do
    max =
      assigns.stages
      |> Enum.map(&((&1.deals_amount && Decimal.to_float(&1.deals_amount.amount)) || 0))
      |> Enum.max(fn -> 0 end)

    assigns = assign(assigns, max: max)

    ~H"""
    <ul class="space-y-4">
      <li :for={stage <- @stages}>
        <div class="mb-1.5 flex items-center justify-between text-sm">
          <span class="flex items-center gap-2 text-ink-soft">
            <span class={["size-2 rounded-full", dot_color(stage.color)]} />
            {stage.name}
            <span class="text-xs text-muted">· {stage.deals_count}</span>
          </span>
          <span class="tabular font-medium text-ink">{Format.money_short(stage.deals_amount)}</span>
        </div>
        <div class="h-1.5 overflow-hidden rounded-full bg-canvas">
          <div
            class={["h-full rounded-full transition-all duration-500", dot_color(stage.color)]}
            style={"width: #{stage_width(stage, @max)}%"}
          />
        </div>
      </li>
    </ul>
    """
  end

  defp stage_width(%{deals_amount: nil}, _max), do: 0
  defp stage_width(_stage, max) when max == 0, do: 0
  defp stage_width(stage, max), do: round(Decimal.to_float(stage.deals_amount.amount) / max * 100)

  @doc "Icon for an activity kind."
  def activity_icon(:call), do: "hero-phone"
  def activity_icon(:email), do: "hero-envelope"
  def activity_icon(:meeting), do: "hero-calendar-days"
  def activity_icon(_), do: "hero-pencil-square"

  @doc """
  Prev / next pager for an `Ash.Page.Offset`. `path` receives the page number.
  """
  attr :page, :map, required: true
  attr :path, :any, required: true

  def pager(assigns) do
    %{offset: offset, limit: limit, count: count, results: results} = assigns.page
    current = div(offset, limit) + 1

    assigns =
      assign(assigns,
        from: if(results == [], do: 0, else: offset + 1),
        to: offset + length(results),
        count: count,
        prev: current > 1 && current - 1,
        next: offset + limit < count && current + 1
      )

    ~H"""
    <div :if={@count > 0} class="mt-4 flex items-center justify-between text-sm text-muted">
      <span class="tabular">{@from}–{@to} of {@count}</span>
      <div class="flex gap-2">
        <.button :if={@prev} patch={@path.(@prev)} size="sm"><.icon name="hero-chevron-left-micro" />
        Prev</.button>
        <.button :if={@next} patch={@path.(@next)} size="sm">Next
        <.icon name="hero-chevron-right-micro" /></.button>
      </div>
    </div>
    """
  end

  @doc "Search box that pushes `search` events as you type."
  attr :id, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search…"

  def search_box(assigns) do
    ~H"""
    <form id={@id} phx-change="search" phx-submit="search" class="relative w-full sm:w-72">
      <.icon
        name="hero-magnifying-glass"
        class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
      />
      <input
        type="search"
        name="q"
        value={@value}
        placeholder={@placeholder}
        phx-debounce="250"
        autocomplete="off"
        class="h-9 w-full rounded-lg border border-line bg-surface pr-3 pl-9 text-sm text-ink shadow-card placeholder:text-muted focus:border-brand focus:ring-3 focus:ring-brand/15 focus:outline-none"
      />
    </form>
    """
  end

  @doc "Segmented filter control rendered as patch links."
  attr :options, :list, required: true, doc: "list of {label, value, path}"
  attr :current, :any, required: true

  def segmented(assigns) do
    ~H"""
    <div class="inline-flex rounded-lg bg-surface p-0.5 shadow-card ring-1 ring-line">
      <.link
        :for={{label, value, path} <- @options}
        patch={path}
        class={[
          "rounded-md px-3 py-1.5 text-xs font-medium transition",
          @current == value && "bg-canvas text-ink",
          @current != value && "text-muted hover:text-ink"
        ]}
      >
        {label}
      </.link>
    </div>
    """
  end

  @doc "Underlined tab button that pushes a `tab` event to `target`."
  attr :target, :any, required: true
  attr :tab, :atom, required: true
  attr :current, :atom, required: true
  slot :inner_block, required: true

  def tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="tab"
      phx-value-tab={@tab}
      phx-target={@target}
      class={[
        "-mb-px border-b-2 px-3 pb-2.5 text-sm font-medium transition",
        @current == @tab && "border-brand text-ink",
        @current != @tab && "border-transparent text-muted hover:text-ink"
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "Round checkbox that toggles a task (`toggle_task` event)."
  attr :task, :map, required: true
  attr :target, :any, required: true

  def task_check(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="toggle_task"
      phx-value-id={@task.id}
      phx-target={@target}
      class={[
        "flex size-5 shrink-0 items-center justify-center rounded-full border transition",
        @task.done? && "border-success bg-success text-white",
        !@task.done? && "border-line-strong hover:border-success hover:bg-success-soft"
      ]}
      aria-label={if(@task.done?, do: "Reopen task", else: "Complete task")}
    >
      <.icon :if={@task.done?} name="hero-check-micro" class="size-3.5" />
    </button>
    """
  end

  @doc "Searchable contact/company field (wraps `ZippikerWeb.Components.PartyPicker`)."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :kind, :atom, default: nil, values: [nil, :person, :organization]
  attr :placeholder, :string, default: "Search…"
  attr :current_user, :map, required: true
  attr :current_organization, :map, required: true

  def party_picker(assigns) do
    assigns =
      assign(
        assigns,
        :errors,
        if(Phoenix.Component.used_input?(assigns.field),
          do: Enum.map(assigns.field.errors, &translate_error/1),
          else: []
        )
      )

    ~H"""
    <.live_component
      module={ZippikerWeb.Components.PartyPicker}
      id={"#{@field.id}_picker"}
      name={@field.name}
      value={@field.value}
      kind={@kind}
      label={@label}
      placeholder={@placeholder}
      errors={@errors}
      current_user={@current_user}
      current_organization={@current_organization}
    />
    """
  end

  @doc """
  Dropdown filters for select, multi-select and yes/no custom fields.
  Pushes `filter_cf` with `%{"cf" => %{key => value}}`.
  """
  attr :id, :string, required: true
  attr :definitions, :list, required: true
  attr :values, :map, default: %{}

  def custom_field_filters(assigns) do
    ~H"""
    <form
      :if={@definitions != []}
      id={@id}
      phx-change="filter_cf"
      class="flex flex-wrap items-center gap-2"
    >
      <.icon name="hero-funnel-micro" class="size-4 text-muted" />
      <select
        :for={definition <- @definitions}
        name={"cf[#{definition.key}]"}
        class={[
          "h-8 rounded-lg border bg-surface px-2 pr-7 text-xs shadow-card focus:border-brand focus:outline-none",
          Map.get(@values, definition.key) && "border-brand text-ink",
          !Map.get(@values, definition.key) && "border-line text-muted"
        ]}
      >
        <option value="">{definition.label}: any</option>
        {Phoenix.HTML.Form.options_for_select(
          filter_options(definition),
          Map.get(@values, definition.key)
        )}
      </select>
    </form>
    """
  end

  defp filter_options(%{type: :boolean, label: label}),
    do: [{"#{label}: yes", "true"}, {"#{label}: no", "false"}]

  defp filter_options(%{options: options, label: label}),
    do: Enum.map(options, &{"#{label}: #{&1}", &1})
end
