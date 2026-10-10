defmodule ZippikerWeb.EmployeeLive.Show do
  @moduledoc "An employee's profile: job, reporting line, leave balances and history, pay (if allowed)."
  use ZippikerWeb, :live_view

  alias Zippiker.{Extensibility, HR}

  @loads [
    :name,
    :email,
    :phone,
    :party,
    :department,
    :user,
    :on_leave_today?,
    :leave_policy,
    manager: [:name],
    direct_reports: [:name]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case HR.get_employee(id, ash_opts(socket) ++ [load: @loads]) do
      {:ok, employee} ->
        {:ok,
         socket
         |> assign(:definitions, Extensibility.list_custom_fields!(:employee, ash_opts(socket)))
         |> load(employee)}

      {:error, _} ->
        {:ok,
         socket |> put_flash(:error, "Employee not found") |> push_navigate(to: ~p"/hr/employees")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :terminating?, socket.assigns.live_action == :terminate)}
  end

  @impl true
  def handle_event("terminate", %{"termination" => params}, socket) do
    case HR.terminate_employee(socket.assigns.employee, params, ash_opts(socket)) do
      {:ok, employee} ->
        {:noreply,
         socket
         |> load(Ash.load!(employee, @loads, ash_opts(socket)))
         |> put_flash(:info, "#{socket.assigns.employee.name} marked as left")
         |> push_patch(to: ~p"/hr/employees/#{employee}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("rehire", _params, socket) do
    employee = HR.rehire_employee!(socket.assigns.employee, ash_opts(socket))

    {:noreply,
     socket
     |> load(Ash.load!(employee, @loads, ash_opts(socket)))
     |> put_flash(:info, "Welcome back!")}
  end

  defp load(socket, employee) do
    opts = ash_opts(socket)

    socket
    |> assign(employee: employee, page_title: employee.name)
    |> assign(:balances, HR.leave_balances!(employee.id, opts))
    |> stream(
      :requests,
      HR.list_leave_requests!(%{employee_id: employee.id}, opts ++ [page: [limit: 20]]).results,
      reset: true
    )
  end

  defp per(:monthly), do: "month"
  defp per(:biweekly), do: "two weeks"
  defp per(:weekly), do: "week"
  defp per(:hourly), do: "hour"
  defp per(:yearly), do: "year"

  # Field policies hide pay and personal details from other members.
  defp visible?(%Ash.ForbiddenField{}), do: false
  defp visible?(_value), do: true
end
