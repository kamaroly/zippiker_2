defmodule ZippikerWeb.HRLive.Departments do
  @moduledoc "Departments with their head, parent and headcount; admins manage them."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Departments") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form_for(socket, nil, AshPhoenix.Form.for_create(HR.Department, :create, form_opts(socket)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    department = HR.get_department!(id, ash_opts(socket))

    form_for(
      socket,
      department,
      AshPhoenix.Form.for_update(department, :update, form_opts(socket))
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, department: nil)

  defp form_opts(socket) do
    [
      as: "department",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]
  end

  defp form_for(socket, department, form) do
    opts = ash_opts(socket)

    socket
    |> assign(form: to_form(form), department: department)
    |> assign(:heads, Enum.map(HR.list_employees!(%{status: :active}, opts), &{&1.name, &1.id}))
    |> assign(
      :parents,
      for(
        d <- HR.list_departments!(opts),
        d.id != (department && department.id),
        do: {d.name, d.id}
      )
    )
  end

  @impl true
  def handle_event("validate", %{"department" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"department" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _department} ->
        {:noreply,
         socket
         |> put_flash(:info, "Department saved")
         |> load()
         |> push_patch(to: ~p"/hr/departments")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> HR.get_department!(opts) |> HR.delete_department(opts) do
      :ok -> {:noreply, socket |> put_flash(:info, "Department deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket),
    do: stream(socket, :departments, HR.list_departments!(ash_opts(socket)), reset: true)
end
