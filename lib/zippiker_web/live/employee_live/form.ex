defmodule ZippikerWeb.EmployeeLive.Form do
  @moduledoc "Hire or edit an employee: person, job, reporting line, login, pay and personal details."
  use ZippikerWeb, :live_view

  alias Zippiker.{Extensibility, HR}

  @impl true
  def mount(params, _session, socket) do
    if admin?(socket.assigns) do
      opts = ash_opts(socket)

      {:ok,
       socket
       |> assign(:departments, Enum.map(HR.list_departments!(opts), &{&1.name, &1.id}))
       |> assign(:definitions, Extensibility.list_custom_fields!(:employee, opts))
       |> assign(:members, member_options(socket.assigns))
       |> assign_employee(params)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Only admins can edit employees")
       |> push_navigate(to: ~p"/hr/employees")}
    end
  end

  defp assign_employee(socket, %{"id" => id}) do
    employee = HR.get_employee!(id, ash_opts(socket) ++ [load: [:party]])

    form =
      employee
      |> AshPhoenix.Form.for_update(:update,
        as: "employee",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "first_name" => employee.party.first_name,
          "last_name" => employee.party.last_name,
          "email" => employee.party.email && to_string(employee.party.email),
          "phone" => employee.party.phone
        }
      )
      |> to_form()

    socket
    |> assign(employee: employee, page_title: "Edit #{employee.party.name}")
    |> assign(:managers, manager_options(socket, employee.id))
    |> assign(:form, form)
  end

  defp assign_employee(socket, _params) do
    form =
      HR.Employee
      |> AshPhoenix.Form.for_create(:create,
        as: "employee",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"hire_date" => Date.to_iso8601(Date.utc_today())}
      )
      |> to_form()

    socket
    |> assign(employee: nil, page_title: "New employee")
    |> assign(:managers, manager_options(socket, nil))
    |> assign(:form, form)
  end

  defp manager_options(socket, except_id) do
    for employee <- HR.list_employees!(%{status: :active}, ash_opts(socket)),
        employee.id != except_id,
        do: {employee.name, employee.id}
  end

  @impl true
  def handle_event("validate", %{"employee" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"employee" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee saved")
         |> push_navigate(to: ~p"/hr/employees/#{employee}")}

      {:error, form} ->
        case change_requested(form) do
          nil ->
            {:noreply, assign(socket, :form, form)}

          number ->
            {:noreply,
             socket
             |> put_flash(:info, change_requested_message(number))
             |> push_navigate(to: ~p"/hr/employees")}
        end
    end
  end
end
