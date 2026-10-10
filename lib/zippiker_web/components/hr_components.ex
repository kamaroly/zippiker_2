defmodule ZippikerWeb.HRComponents do
  @moduledoc "People building blocks: leave badges, the org chart tree."
  use Phoenix.Component
  use ZippikerWeb, :verified_routes

  import ZippikerWeb.CoreComponents

  alias ZippikerWeb.Format

  attr :status, :atom, required: true

  def leave_status(assigns) do
    ~H"""
    <.badge color={
      %{pending: :amber, approved: :emerald, rejected: :rose, cancelled: :slate}[@status]
    }>
      {Format.humanize(@status)}
    </.badge>
    """
  end

  attr :type, :map, required: true

  def leave_type_badge(assigns) do
    ~H"""
    <.badge color={@type.color}>
      <span class={["size-1.5 rounded-full", dot_color(@type.color)]} />{@type.name}
    </.badge>
    """
  end

  @doc "`Nov 2 – Nov 6, 2026` (or a single date)."
  def period(%{start_date: from, end_date: to}) when from == to, do: Format.date(from)

  def period(%{start_date: from, end_date: to}),
    do: "#{Calendar.strftime(from, "%b %-d")} – #{Format.date(to)}"

  @doc "One person in the org chart, with their reports nested below."
  attr :node, :map, required: true

  def org_node(assigns) do
    ~H"""
    <li class="org-node">
      <.link
        navigate={~p"/hr/employees/#{@node.employee}"}
        id={"org-#{@node.employee.id}"}
        class="org-card inline-flex min-w-48 items-center gap-3 rounded-xl border border-line bg-surface px-3 py-2.5 text-left shadow-card transition hover:-translate-y-0.5 hover:border-line-strong hover:shadow-pop"
      >
        <.avatar name={@node.employee.name} size="sm" />
        <span class="min-w-0">
          <span class="block truncate text-sm font-semibold text-ink">{@node.employee.name}</span>
          <span class="block truncate text-xs text-muted">
            {@node.employee.job_title || "—"}
            <span :if={@node.employee.on_leave_today?} class="text-warning">· away</span>
          </span>
        </span>
      </.link>
      <ul :if={@node.reports != []} class="org-children">
        <.org_node :for={child <- @node.reports} node={child} />
      </ul>
    </li>
    """
  end
end
