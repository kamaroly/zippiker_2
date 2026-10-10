defmodule ZippikerWeb.LeaveLive.Index do
  @moduledoc """
  Leave: your requests, requests waiting for your decision (as a manager or
  admin), everyone's, and who's away in the next 30 days. Requests are made
  in a modal that shows working days and the balance left.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR
  alias Zippiker.HR.WorkingDays

  @views ~w(mine approve all)

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    me =
      case HR.my_employee_record(opts) do
        {:ok, employee} -> employee
        _ -> nil
      end

    today = Date.utc_today()

    {:ok,
     socket
     |> assign(page_title: "Leave", me: me)
     |> assign(:leave_types, HR.list_leave_types!(%{active_only?: true}, opts))
     |> assign(
       :away,
       HR.list_leave_requests!(
         %{status: :approved, from: today, to: Date.add(today, 30)},
         opts
       )
       |> Enum.sort_by(& &1.start_date, Date)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    default = if socket.assigns.me, do: "mine", else: "approve"
    view = if params["view"] in @views, do: params["view"], else: default

    {:noreply,
     socket
     |> assign(:view, view)
     |> load_requests()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    employee_id =
      if admin?(socket.assigns),
        do: params["employee_id"] || (socket.assigns.me && socket.assigns.me.id),
        else: socket.assigns.me && socket.assigns.me.id

    form =
      HR.LeaveRequest
      |> AshPhoenix.Form.for_create(:create,
        as: "leave",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "employee_id" => employee_id,
          "leave_type_id" => socket.assigns.leave_types |> List.first() |> then(&(&1 && &1.id))
        }
      )
      |> to_form()

    employees =
      if admin?(socket.assigns),
        do:
          Enum.map(
            HR.list_employees!(%{status: :active}, ash_opts(socket)),
            &{&1.name, &1.id}
          ),
        else: []

    socket
    |> assign(employee_options: employees)
    |> assign_form(form)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil)

  @impl true
  def handle_event("validate", %{"leave" => params}, socket) do
    {:noreply, assign_form(socket, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"leave" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(request.status == :approved,
             do: "Leave booked",
             else: "Request sent for approval"
           )
         )
         |> push_patch(to: ~p"/hr/leave?view=mine")}

      {:error, form} ->
        {:noreply, assign_form(socket, form)}
    end
  end

  def handle_event("decide", %{"id" => id, "decision" => decision}, socket) do
    opts = ash_opts(socket)
    request = HR.get_leave_request!(id, opts)

    result =
      if decision == "approve",
        do: HR.approve_leave(request, opts),
        else: HR.reject_leave(request, opts)

    case result do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request #{request.status}")
         |> load_requests()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> HR.get_leave_request!(opts) |> HR.cancel_leave(opts) do
      {:ok, _request} ->
        {:noreply, socket |> put_flash(:info, "Request cancelled") |> load_requests()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load_requests(socket) do
    filters =
      case socket.assigns.view do
        "mine" -> %{mine?: true}
        "approve" -> if admin?(socket.assigns), do: %{status: :pending}, else: %{to_decide?: true}
        "all" -> %{}
      end

    requests = HR.list_leave_requests!(filters, ash_opts(socket) ++ [page: [limit: 50]]).results
    stream(socket, :requests, requests, reset: true)
  end

  # Days and balance preview as the form changes.
  defp assign_form(socket, form) do
    form = to_form(form)
    params = AshPhoenix.Form.params(form)

    days =
      with {:ok, from} <- Date.from_iso8601(params["start_date"] || ""),
           {:ok, to} <- Date.from_iso8601(params["end_date"] || "") do
        WorkingDays.count(from, to)
      else
        _ -> nil
      end

    balance =
      with id when is_binary(id) and id != "" <- params["employee_id"],
           type_id when is_binary(type_id) <- params["leave_type_id"] do
        id
        |> HR.leave_balances!(ash_opts(socket))
        |> Enum.find(&(&1.leave_type.id == type_id))
      else
        _ -> nil
      end

    assign(socket, form: form, days: days, balance: balance)
  end

  defp can_decide?(request, assigns) do
    request.status == :pending and request.employee.user_id != assigns.current_user.id and
      (admin?(assigns) or
         (request.employee.manager && request.employee.manager.user_id == assigns.current_user.id))
  end

  defp can_cancel?(request, assigns) do
    request.status in [:pending, :approved] and
      (admin?(assigns) or request.employee.user_id == assigns.current_user.id)
  end
end
