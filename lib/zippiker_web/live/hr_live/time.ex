defmodule ZippikerWeb.HRLive.Time do
  @moduledoc """
  Time tracking: log hours by day, pay type, customer and project (deal),
  billable or not. Members see and log their own time; admins everyone's.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)
    admin? = admin?(socket.assigns)

    employees =
      if admin?,
        do: HR.list_employees!(%{status: :active}, Keyword.put(opts, :load, [:name])),
        else: []

    customers =
      (Zippiker.Parties.list_parties!(:organization, opts) ++
         Zippiker.Parties.list_parties!(:person, %{role: :customer}, opts))
      |> Enum.sort_by(&String.downcase(&1.name || ""))
      |> Enum.map(&{&1.name, &1.id})

    deals =
      if ZippikerWeb.Modules.enabled?(socket.assigns.current_organization, :crm),
        do: Enum.map(Zippiker.Crm.list_deals!(%{status: :open}, opts), &{&1.title, &1.id}),
        else: []

    {:ok,
     assign(socket,
       page_title: "Time",
       admin?: admin?,
       employee_options: Enum.map(employees, &{&1.name, &1.id}),
       customer_options: customers,
       deal_options: deals,
       pay_types: Enum.map(pay_types(), &{Format.humanize(&1), &1})
     )}
  end

  defp pay_types, do: [:regular, :overtime, :weekend, :holiday, :sick, :vacation, :unpaid]

  @impl true
  def handle_params(params, _url, socket) do
    week = week_start(params["week"])
    employee = if socket.assigns.admin?, do: blank(params["employee"])

    socket =
      socket
      |> assign(week: week, employee: employee, params: params)
      |> load()

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      HR.TimeActivity
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> AshPhoenix.Form.validate(%{"date" => Date.to_iso8601(Date.utc_today()), "hours" => "8"})
      |> to_form()

    assign(socket, form: form, activity: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    activity = HR.get_time_activity!(id, ash_opts(socket))
    form = activity |> AshPhoenix.Form.for_update(:update, form_opts(socket)) |> to_form()
    assign(socket, form: form, activity: activity)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, activity: nil)

  defp form_opts(socket),
    do: [
      as: "time",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]

  @impl true
  def handle_event("validate", %{"time" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"time" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Time saved")
         |> push_patch(to: index_path(socket.assigns))}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    activity = HR.get_time_activity!(id, ash_opts(socket))

    case HR.delete_time_activity(activity, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Time entry removed") |> load()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "You can't remove that entry.")}
    end
  end

  def handle_event("employee", %{"employee" => employee}, socket) do
    {:noreply, push_patch(socket, to: index_path(%{socket.assigns | employee: blank(employee)}))}
  end

  defp load(socket) do
    %{week: week, employee: employee} = socket.assigns

    args =
      %{from: week, to: Date.add(week, 6)}
      |> Map.merge(
        cond do
          employee -> %{employee_id: employee}
          socket.assigns.admin? -> %{}
          true -> %{mine?: true}
        end
      )

    activities = HR.list_time_activities!(args, ash_opts(socket))
    hours = &(activities |> Enum.filter(&1) |> Enum.map(fn a -> a.hours end) |> sum())

    unbilled =
      activities
      |> Enum.filter(&(&1.billable? and is_nil(&1.invoice_id) and &1.hourly_rate))
      |> Enum.map(&Decimal.mult(&1.hours, &1.hourly_rate))
      |> sum()

    socket
    |> assign(
      total_hours: hours.(fn _ -> true end),
      billable_hours: hours.(& &1.billable?),
      unbilled: unbilled,
      days: day_totals(activities, week),
      empty?: activities == []
    )
    |> stream(:activities, activities, reset: true)
  end

  defp day_totals(activities, week) do
    for offset <- 0..6 do
      day = Date.add(week, offset)

      {day, activities |> Enum.filter(&(&1.date == day)) |> Enum.map(& &1.hours) |> sum()}
    end
  end

  defp sum(values), do: Enum.reduce(values, Decimal.new(0), &Decimal.add/2)

  defp week_start(value) do
    date =
      case Date.from_iso8601(value || "") do
        {:ok, date} -> date
        _ -> Date.utc_today()
      end

    Date.beginning_of_week(date)
  end

  defp blank(value) when value in [nil, ""], do: nil
  defp blank(value), do: value

  defp index_path(assigns, week \\ nil) do
    query_path(~p"/hr/time", %{
      week: week || assigns.week,
      employee: assigns.employee
    })
  end

  defp hours(value), do: ZippikerWeb.ReportComponents.cell(value, :number)

  defp can_edit?(activity, assigns) do
    assigns.admin? or
      (is_nil(activity.invoice_id) and activity.employee.user_id == assigns.current_user.id)
  end
end
