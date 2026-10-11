defmodule ZippikerWeb.HRLive.Holidays do
  @moduledoc "Public holidays: leave doesn't count them unless the leave policy says so."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Holidays") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      HR.Holiday
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> to_form()

    assign(socket, form: form, holiday: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    holiday = HR.get_holiday!(id, ash_opts(socket))
    form = holiday |> AshPhoenix.Form.for_update(:update, form_opts(socket)) |> to_form()
    assign(socket, form: form, holiday: holiday)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, holiday: nil)

  defp form_opts(socket),
    do: [
      as: "holiday",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]

  @impl true
  def handle_event("validate", %{"holiday" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"holiday" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _holiday} ->
        {:noreply,
         socket |> put_flash(:info, "Holiday saved") |> load() |> push_patch(to: ~p"/hr/holidays")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    holiday = HR.get_holiday!(id, ash_opts(socket))
    :ok = HR.delete_holiday(holiday, ash_opts(socket))
    {:noreply, socket |> put_flash(:info, "Holiday removed") |> load()}
  end

  defp load(socket),
    do: stream(socket, :holidays, HR.list_holidays!(ash_opts(socket)), reset: true)

  # Recurring holidays show this year's (or next year's) date.
  defp next_date(%{recurring?: true, date: date}) do
    today = Date.utc_today()

    case Date.new(today.year, date.month, date.day) do
      {:ok, day} -> if Date.compare(day, today) == :lt, do: Date.shift(day, year: 1), else: day
      _ -> date
    end
  end

  defp next_date(%{date: date}), do: date
end
