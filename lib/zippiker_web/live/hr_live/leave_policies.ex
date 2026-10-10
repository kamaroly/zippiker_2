defmodule ZippikerWeb.HRLive.LeavePolicies do
  @moduledoc """
  Leave policies: which leave types apply, days per year and carry-over, and
  who's on each policy. The default policy covers everyone not assigned.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Leave policies") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      HR.LeavePolicy
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> to_form()

    assign(socket, form: form, policy: nil, editing: :details)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    policy = find(socket, id)

    form =
      policy
      |> AshPhoenix.Form.for_update(:update, form_opts(socket))
      |> to_form()

    assign(socket, form: form, policy: policy, editing: :details)
  end

  defp apply_action(socket, :rules, %{"id" => id}) do
    assign(socket, form: nil, policy: find(socket, id), editing: :rules)
  end

  defp apply_action(socket, :assign, %{"id" => id}) do
    employees =
      HR.list_employees!(%{status: :active}, ash_opts(socket) ++ [load: [:leave_policy]])

    socket
    |> assign(form: nil, policy: find(socket, id), editing: :assign)
    |> assign(:employees, employees)
    |> assign(:departments, HR.list_departments!(ash_opts(socket)))
  end

  defp apply_action(socket, :index, _params),
    do: assign(socket, form: nil, policy: nil, editing: nil)

  defp form_opts(socket) do
    [
      as: "policy",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]
  end

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
         |> put_flash(:info, "Policy saved")
         |> load()
         |> push_patch(
           to:
             if(socket.assigns.policy,
               do: ~p"/hr/leave-policies",
               else: ~p"/hr/leave-policies/#{policy}/rules"
             )
         )}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("save_rules", %{"rules" => rules}, socket) do
    case HR.set_leave_policy_rules(socket.assigns.policy, Map.values(rules), ash_opts(socket)) do
      {:ok, _policy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Entitlements saved")
         |> load()
         |> push_patch(to: ~p"/hr/leave-policies")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
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
         |> put_flash(:info, "Employees assigned")
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

  defp load(socket) do
    opts = ash_opts(socket)

    assign(socket,
      policies: HR.list_leave_policies!(opts),
      leave_types: HR.list_leave_types!(%{active_only?: true}, opts)
    )
  end

  defp rule(policy, type), do: Enum.find(policy.rules, &(&1.leave_type_id == type.id))

  defp days(nil), do: ""
  defp days(value), do: Decimal.to_string(Decimal.normalize(value), :normal)
end
