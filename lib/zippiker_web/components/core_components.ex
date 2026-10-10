defmodule ZippikerWeb.CoreComponents do
  @moduledoc """
  Core UI building blocks: buttons, inputs, tables, cards, modals, badges.

  Everything is plain Tailwind on top of the design tokens defined in
  `assets/css/app.css` (`bg-surface`, `text-muted`, `border-line`, `bg-brand`...),
  so light and dark mode come for free.
  """
  use Phoenix.Component
  use Gettext, backend: ZippikerWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a flash toast.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed bottom-5 right-5 z-50 w-80 sm:w-96 cursor-pointer animate-rise"
      {@rest}
    >
      <div class="flex items-start gap-3 rounded-xl border border-line bg-surface p-4 shadow-pop">
        <span class={[
          "mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full",
          @kind == :info && "bg-success-soft text-success",
          @kind == :error && "bg-danger-soft text-danger"
        ]}>
          <.icon :if={@kind == :info} name="hero-check-micro" class="size-4" />
          <.icon :if={@kind == :error} name="hero-exclamation-triangle-micro" class="size-4" />
        </span>
        <div class="min-w-0 flex-1 text-sm">
          <p :if={@title} class="font-semibold text-ink">{@title}</p>
          <p class="text-ink-soft">{msg}</p>
        </div>
        <.icon name="hero-x-mark-micro" class="size-4 text-muted" />
      </div>
    </div>
    """
  end

  @size_classes %{"sm" => "h-8 px-3 text-xs", "md" => "h-9 px-3.5 text-sm"}
  @variant_classes %{
    "primary" => "bg-brand text-brand-ink shadow-card hover:brightness-105",
    "secondary" =>
      "border border-line bg-surface text-ink shadow-card hover:bg-surface-muted hover:border-line-strong",
    "ghost" => "text-ink-soft hover:bg-canvas hover:text-ink",
    "danger" => "border border-line bg-surface text-danger hover:bg-danger-soft"
  }

  @doc """
  Renders a button or a link styled as a button.

  ## Examples

      <.button>Save</.button>
      <.button variant="primary" phx-click="go">Go</.button>
      <.button navigate={~p"/"} variant="ghost">Home</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled form type)

  attr :class, :any, default: nil
  attr :variant, :string, default: "secondary", values: ~w(primary secondary ghost danger)
  attr :size, :string, default: "md", values: ~w(sm md)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :classes, [
        "inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-lg font-medium",
        "transition-all duration-150 active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand",
        "phx-submit-loading:opacity-70 phx-click-loading:opacity-70",
        @size_classes[assigns.size],
        @variant_classes[assigns.variant],
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  Accepts a `Phoenix.HTML.FormField` via `field`, or `name`/`value` directly.
  Types: text, email, number, date, url, tel, password, textarea, select, checkbox, hidden.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label class="inline-flex cursor-pointer items-center gap-2.5 text-sm text-ink">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "size-4 rounded border-line-strong accent-brand"}
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={[@class || field_classes(), "pr-8", @errors != [] && (@error_class || error_classes())]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@hint} class="mt-1 text-xs text-muted">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          @class || field_classes(),
          "min-h-24 py-2",
          @errors != [] && (@error_class || error_classes())
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@hint} class="mt-1 text-xs text-muted">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@class || field_classes(), @errors != [] && (@error_class || error_classes())]}
        {@rest}
      />
      <p :if={@hint} class="mt-1 text-xs text-muted">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp field_classes do
    "block h-9 w-full rounded-lg border border-line bg-surface px-3 text-sm text-ink shadow-card " <>
      "placeholder:text-muted transition-colors focus:border-brand focus:outline-none " <>
      "focus:ring-3 focus:ring-brand/15"
  end

  defp error_classes, do: "border-danger focus:border-danger focus:ring-danger/15"

  @doc "Renders a form label."
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="mb-1.5 block text-xs font-medium text-ink-soft">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc "Renders an error message under an input."
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1 text-xs text-danger">
      <.icon name="hero-exclamation-circle-micro" class="size-3.5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page header with title, optional subtitle and actions.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions
  slot :breadcrumb

  def header(assigns) do
    ~H"""
    <header class="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div class="min-w-0">
        <div :if={@breadcrumb != []} class="mb-1 text-xs text-muted">{render_slot(@breadcrumb)}</div>
        <h1 class="truncate text-2xl font-semibold tracking-tight text-ink">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-muted">{render_slot(@subtitle)}</p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-2">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc "A white card. Optional `title` and `action` slot render a header row."
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  attr :padded, :boolean, default: true
  attr :rest, :global
  slot :inner_block, required: true
  slot :action

  def card(assigns) do
    ~H"""
    <section class={["rounded-2xl border border-line bg-surface shadow-card", @class]} {@rest}>
      <div :if={@title} class="flex items-center justify-between gap-3 px-5 pt-4 pb-1">
        <h2 class="text-sm font-semibold text-ink">{@title}</h2>
        <div :if={@action != []} class="text-xs">{render_slot(@action)}</div>
      </div>
      <div class={@padded && "p-5"}>{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  Renders a table. Works with streams.

  ## Examples

      <.table id="users" rows={@streams.users} row_click={fn {_id, user} -> JS.navigate(user_path(user)) end}>
        <:col :let={{_id, user}} label="Name">{user.name}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"
  slot :empty, doc: "rendered when there are no rows"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto rounded-2xl border border-line bg-surface shadow-card">
      <table class="w-full text-left text-sm">
        <thead>
          <tr class="border-b border-line text-xs text-muted">
            <th :for={col <- @col} class={["px-5 py-3 font-medium", col[:class]]}>{col[:label]}</th>
            <th :if={@action != []} class="px-5 py-3">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-line"
        >
          <tr :if={@empty != []} id={"#{@id}-empty"} class="hidden only:table-row">
            <td colspan={length(@col) + 1} class="px-5 py-14 text-center">{render_slot(@empty)}</td>
          </tr>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={["group transition-colors", @row_click && "cursor-pointer hover:bg-surface-muted"]}
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-5 py-3 text-ink-soft", col[:class]]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 px-5 py-3">
              <div class="flex justify-end gap-3 text-xs font-medium">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a definition list.

      <.list>
        <:item title="Email">{@user.email}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-line text-sm">
      <div :for={item <- @item} class="flex gap-4 py-2.5">
        <dt class="w-32 shrink-0 text-muted">{item.title}</dt>
        <dd class="min-w-0 flex-1 break-words text-ink">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  A modal dialog. Show it by rendering it (e.g. on a live_action) and
  pass `on_cancel` to navigate away when closed.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: nil
  attr :on_cancel, JS, default: %JS{}
  attr :size, :string, default: "md", values: ~w(md lg)
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-40 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-ink/30 backdrop-blur-[2px] transition-opacity"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true" tabindex="0">
        <div class="flex min-h-full items-start justify-center p-4 sm:pt-[10vh]">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={[
              "relative w-full rounded-2xl border border-line bg-surface shadow-pop",
              @size == "md" && "max-w-lg",
              @size == "lg" && "max-w-2xl"
            ]}
          >
            <div class="flex items-center justify-between border-b border-line px-6 py-4">
              <h2 class="text-base font-semibold text-ink">{@title}</h2>
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="-mr-2 rounded-lg p-1.5 text-muted transition hover:bg-canvas hover:text-ink"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            <div id={"#{@id}-content"} class="px-6 py-5">{render_slot(@inner_block)}</div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  @doc "A small pill. Colors map to the stage palette and semantic tokens."
  attr :color, :atom, default: :slate
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap",
      badge_color(@color),
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc false
  def badge_color(color) do
    %{
      slate: "bg-canvas text-ink-soft ring-1 ring-line",
      blue: "bg-info-soft text-info",
      violet: "bg-violet-500/10 text-violet-600 dark:text-violet-300",
      amber: "bg-warning-soft text-warning",
      emerald: "bg-success-soft text-success",
      rose: "bg-danger-soft text-danger",
      orange: "bg-brand-soft text-brand",
      teal: "bg-teal-500/10 text-teal-600 dark:text-teal-300"
    }[color] || "bg-canvas text-ink-soft"
  end

  @doc "Solid dot color for a palette name (stage colors, charts)."
  def dot_color(color) do
    %{
      slate: "bg-stone-400",
      blue: "bg-blue-500",
      violet: "bg-violet-500",
      amber: "bg-amber-500",
      emerald: "bg-emerald-500",
      rose: "bg-rose-500",
      orange: "bg-orange-500",
      teal: "bg-teal-500"
    }[color] || "bg-stone-400"
  end

  @doc "Initials avatar with a stable color derived from the name."
  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(xs sm md lg)
  attr :square, :boolean, default: false

  def avatar(assigns) do
    ~H"""
    <span
      title={@name}
      class={[
        "inline-flex shrink-0 select-none items-center justify-center font-semibold",
        if(@square, do: "rounded-lg", else: "rounded-full"),
        avatar_size(@size),
        avatar_palette(@name)
      ]}
    >
      {initials(@name)}
    </span>
    """
  end

  defp avatar_size("xs"), do: "size-5 text-[9px]"
  defp avatar_size("sm"), do: "size-7 text-[11px]"
  defp avatar_size("md"), do: "size-9 text-xs"
  defp avatar_size("lg"), do: "size-14 text-lg"

  @avatar_palettes [
    "bg-orange-100 text-orange-700 dark:bg-orange-500/15 dark:text-orange-300",
    "bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300",
    "bg-violet-100 text-violet-700 dark:bg-violet-500/15 dark:text-violet-300",
    "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300",
    "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300",
    "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300",
    "bg-teal-100 text-teal-700 dark:bg-teal-500/15 dark:text-teal-300"
  ]

  defp avatar_palette(name),
    do: Enum.at(@avatar_palettes, :erlang.phash2(name || "", length(@avatar_palettes)))

  defp initials(name) do
    (name || "?")
    |> String.split(~r/[\s@._-]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  @doc "Friendly empty state."
  attr :icon, :string, default: "hero-sparkles"
  attr :title, :string, required: true
  slot :inner_block
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center px-6 py-10 text-center">
      <span class="mb-3 flex size-11 items-center justify-center rounded-full bg-brand-soft text-brand">
        <.icon name={@icon} class="size-5" />
      </span>
      <p class="text-sm font-semibold text-ink">{@title}</p>
      <p :if={@inner_block != []} class="mt-1 max-w-xs text-sm text-muted">
        {render_slot(@inner_block)}
      </p>
      <div :if={@action != []} class="mt-4">{render_slot(@action)}</div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-out duration-200", "opacity-0 translate-y-1",
         "opacity-100 translate-y-0"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all ease-in duration-150", "opacity-100 translate-y-0",
         "opacity-0 translate-y-1"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-opacity ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 150,
      transition: {"transition-opacity ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(ZippikerWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ZippikerWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
