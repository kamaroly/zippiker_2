defmodule ZippikerWeb.HRLive.LeavePolicies do
  @moduledoc """
  Leave policies, one per leave type: how days are granted (fixed yearly,
  accrual, manual, unlimited), from when, and the request rules. Admins
  assign people to them; each leave type's default policy covers everyone
  else. Accruals run daily (Oban) and can be run on demand.
  """
  use ZippikerWeb, :live_view

  require Ash.Query

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Leave policies") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    type_id = params["leave_type_id"] || List.first(socket.assigns.leave_types, %{id: nil}).id

    form =
      HR.LeavePolicy
      |> AshPhoenix.Form.for_create(:create,
        as: "policy",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "leave_type_id" => type_id,
          "effective_date" => Date.to_iso8601(Date.utc_today()),
          "category" => "fixed",
          "allow_backdated?" => "true",
          "carry_over_days" => "0"
        }
      )
      |> to_form()

    assign(socket, form: form, policy: nil, editing: :details)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    policy = find(socket, id)

    form =
      policy
      |> AshPhoenix.Form.for_update(:update,
        as: "policy",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, policy: policy, editing: :details)
  end

  defp apply_action(socket, :assign, %{"id" => id}) do
    policy = find(socket, id)
    opts = ash_opts(socket)

    assignments =
      HR.LeavePolicyAssignment
      |> Ash.Query.filter(leave_type_id == ^policy.leave_type_id)
      |> Ash.Query.load(:leave_policy)
      |> Ash.read!(opts)
      |> Map.new(&{&1.employee_id, &1.leave_policy})

    socket
    |> assign(form: nil, policy: policy, editing: :assign, assignments: assignments)
    |> assign(:employees, HR.list_employees!(%{status: :active}, opts))
    |> assign(:departments, HR.list_departments!(opts))
  end

  defp apply_action(socket, :index, _params),
    do: assign(socket, form: nil, policy: nil, editing: nil)

  defp find(socket, id), do: Enum.find(socket.assigns.policies, &(&1.id == id))

  @impl true
  def handle_event("validate", %{"policy" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"policy" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, policy} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{policy.name} saved")
         |> load()
         |> push_patch(
           to:
             if(socket.assigns.policy || policy.default?,
               do: ~p"/hr/leave-policies",
               else: ~p"/hr/leave-policies/#{policy}/assign"
             )
         )}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("save_assign", params, socket) do
    ids = params |> Map.get("employee_ids", []) |> Enum.reject(&(&1 == ""))

    department_id =
      if params["department_id"] in [nil, ""], do: nil, else: params["department_id"]

    case HR.assign_leave_policy(
           socket.assigns.policy,
           %{employee_ids: ids, department_id: department_id},
           ash_opts(socket)
         ) do
      {:ok, _policy} ->
        {:noreply,
         socket
         |> put_flash(:info, "People assigned")
         |> load()
         |> push_patch(to: ~p"/hr/leave-policies")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case HR.delete_leave_policy(find(socket, id), ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Policy deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("run_accruals", _params, socket) do
    case HR.run_leave_accruals(%{}, ash_opts(socket)) do
      {:ok, %{credited: credited}} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "Accruals are up to date (#{Format.count(credited, "new entry")})"
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket) do
    opts = ash_opts(socket)

    assign(socket,
      policies: HR.list_leave_policies!(opts),
      leave_types: HR.list_leave_types!(%{active_only?: true}, opts)
    )
  end

  defp policies_for(policies, type), do: Enum.filter(policies, &(&1.leave_type_id == type.id))

  @doc false
  def days(nil), do: nil
  def days(value), do: value |> Decimal.normalize() |> Decimal.to_string(:normal)

  @doc "One line describing how the policy grants days."
  def grant_summary(%{category: :unlimited}), do: "Unlimited"
  def grant_summary(%{category: :manual}), do: "Manual balance: admins add days"

  def grant_summary(%{category: :fixed} = policy) do
    base =
      if policy.days_per_year,
        do: "#{days(policy.days_per_year)} days / year",
        else: "No limit"

    if Decimal.gt?(policy.carry_over_days, 0),
      do: "#{base} · carry over up to #{days(policy.carry_over_days)}",
      else: base
  end

  def grant_summary(%{category: :accrual} = policy) do
    base = "Earns #{days(policy.accrual_days)} days #{frequency(policy.accrual_frequency)}"
    if policy.accrual_cap, do: "#{base} · cap #{days(policy.accrual_cap)}", else: base
  end

  defp frequency(:weekly), do: "every week"
  defp frequency(:monthly), do: "every month"
  defp frequency(:quarterly), do: "every quarter"
  defp frequency(:yearly), do: "every year"

  @doc "Short labels for the request rules that are switched on."
  def rule_chips(policy) do
    [
      policy.requires_attachment? && "File required",
      policy.count_weekends_and_holidays? && "Counts weekends & holidays",
      !policy.allow_backdated? && "No backdating",
      policy.claimable? && "Claimable",
      policy.overdue_action != :none && policy.review_threshold_days &&
        "Auto-#{if policy.overdue_action == :approve, do: "approve", else: "reject"} after #{policy.review_threshold_days} days"
    ]
    |> Enum.filter(& &1)
  end
end
