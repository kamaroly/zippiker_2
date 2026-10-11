defmodule ZippikerWeb.HRLive.LeaveTypes do
  @moduledoc "Kinds of leave with yearly allowance, pay and approval settings."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @colors ~w(blue emerald amber rose violet teal orange slate)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Leave types", colors: @colors) |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      HR.LeaveType
      |> AshPhoenix.Form.for_create(:create,
        as: "leave_type",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, leave_type: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    leave_type = HR.get_leave_type!(id, ash_opts(socket))

    form =
      leave_type
      |> AshPhoenix.Form.for_update(:update,
        as: "leave_type",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, leave_type: leave_type)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, leave_type: nil)

  @impl true
  def handle_event("validate", %{"leave_type" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"leave_type" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _type} ->
        {:noreply,
         socket
         |> put_flash(:info, "Leave type saved")
         |> load()
         |> push_patch(to: ~p"/hr/leave-types")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    type = HR.get_leave_type!(id, ash_opts(socket))

    case HR.delete_leave_type(type, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "#{type.name} deleted") |> load()}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{type.name} has leave requests or claims; untick Active to retire it instead"
         )}
    end
  end

  defp load(socket),
    do: stream(socket, :leave_types, HR.list_leave_types!(ash_opts(socket)), reset: true)
end
