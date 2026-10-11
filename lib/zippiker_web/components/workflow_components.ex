defmodule ZippikerWeb.WorkflowComponents do
  @moduledoc """
  Approval building blocks shared by every approvable document: links to
  the document, type and status badges, and the step-by-step timeline.
  """
  use Phoenix.Component
  use ZippikerWeb, :verified_routes

  import ZippikerWeb.CoreComponents

  alias ZippikerWeb.Format

  @doc "Where an approval request's document lives in the app."
  def document_path(%{document_type: :expense_claim, document_id: id}), do: ~p"/expenses/#{id}"
  def document_path(%{document_type: :leave_request}), do: ~p"/hr/leave?view=approve"
  def document_path(_request), do: nil

  attr :type, :atom, required: true

  def document_type_badge(assigns) do
    ~H"""
    <.badge color={:blue}>{Zippiker.Workflow.DocumentTypes.label(@type)}</.badge>
    """
  end

  attr :status, :atom, required: true

  def approval_status(assigns) do
    ~H"""
    <.badge color={
      %{pending: :amber, approved: :emerald, rejected: :rose, cancelled: :slate}[@status]
    }>
      {if @status == :pending, do: "In approval", else: Format.humanize(@status)}
    </.badge>
    """
  end

  @doc "Who decides a workflow step, in words."
  def approver_label(%{approver_type: :manager}), do: "Initiator's manager"
  def approver_label(%{approver_type: :admins}), do: "Any workspace admin"

  def approver_label(%{approver_type: :manager_or_admins}),
    do: "Initiator's manager (or an admin)"

  def approver_label(%{approver_type: :user, user: %{} = user}), do: Format.user_name(user)
  def approver_label(%{approver_type: :user}), do: "A specific person"

  def approver_label(%{approver_type: :group, group: %{name: name}}), do: "Anyone in #{name}"
  def approver_label(%{approver_type: :group}), do: "A group"

  @doc "Step-by-step progress of an approval request, initiator first."
  attr :request, :map, required: true
  attr :id, :string, default: "approval-timeline"

  def approval_timeline(assigns) do
    ~H"""
    <ol id={@id} class="relative space-y-4 border-l border-line pl-5">
      <li class="relative">
        <span class="absolute -left-[27px] top-0.5 grid size-4 place-items-center rounded-full bg-ink text-surface ring-4 ring-surface">
          <.icon name="hero-paper-airplane-micro" class="size-2.5" />
        </span>
        <p class="text-sm font-medium text-ink">Submitted</p>
        <p class="text-xs text-muted">
          {Format.user_name(@request.requested_by)} · {Format.date(@request.inserted_at)}
        </p>
      </li>
      <li
        :for={step <- @request.steps}
        id={"#{@id}-step-#{step.position}"}
        class={["relative", step.status in [:waiting, :skipped] && "opacity-60"]}
      >
        <span class={[
          "absolute -left-[27px] top-0.5 grid size-4 place-items-center rounded-full ring-4 ring-surface",
          step_dot(step.status)
        ]}>
          <.icon name={step_icon(step.status)} class="size-2.5" />
        </span>
        <p class="flex flex-wrap items-center gap-2 text-sm font-medium text-ink">
          {step.label || "Approver #{step.position}"}
          <span
            :if={step.position == length(@request.steps)}
            class="rounded bg-canvas px-1.5 py-px text-[10px] font-semibold tracking-wide text-muted uppercase"
          >
            Final
          </span>
        </p>
        <p class="text-xs text-muted">
          {step_summary(step)}
        </p>
        <p
          :if={step.comment}
          class="mt-1.5 rounded-lg bg-canvas px-2.5 py-1.5 text-xs text-ink-soft"
        >
          “{step.comment}”
        </p>
      </li>
    </ol>
    """
  end

  defp step_summary(%{status: :approved} = step),
    do: "Approved by #{Format.user_name(step.decided_by)} · #{Format.date(step.decided_at)}"

  defp step_summary(%{status: :rejected} = step),
    do: "Rejected by #{Format.user_name(step.decided_by)} · #{Format.date(step.decided_at)}"

  defp step_summary(%{status: :pending} = step), do: "Waiting on #{approver_label(step)}"
  defp step_summary(%{status: :skipped}), do: "Skipped: nobody else to ask"
  defp step_summary(step), do: "Then #{approver_label(step)}"

  defp step_dot(:approved), do: "bg-success text-white"
  defp step_dot(:rejected), do: "bg-danger text-white"
  defp step_dot(:pending), do: "bg-warning text-white animate-pulse"
  defp step_dot(_status), do: "bg-line text-muted"

  defp step_icon(:approved), do: "hero-check-micro"
  defp step_icon(:rejected), do: "hero-x-mark-micro"
  defp step_icon(:pending), do: "hero-clock-micro"
  defp step_icon(:skipped), do: "hero-forward-micro"
  defp step_icon(_status), do: "hero-ellipsis-horizontal-micro"
end
