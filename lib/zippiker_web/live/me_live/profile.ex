defmodule ZippikerWeb.MeLive.Profile do
  @moduledoc """
  Self-service profile: your job details (read-only) and the contact
  details you keep up to date yourself (phone, emergency contact).
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    case HR.my_employee_record(opts) do
      {:ok, employee} ->
        employee =
          Ash.load!(
            employee,
            [:name, :email, :phone, :department, :leave_policies, manager: [:name]],
            opts
          )

        form =
          employee
          |> AshPhoenix.Form.for_update(:update_self,
            as: "me",
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_organization,
            params: %{"phone" => employee.phone}
          )
          |> to_form()

        {:ok, assign(socket, page_title: "My profile", employee: employee, form: form)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Your login isn't linked to an employee record yet")
         |> push_navigate(to: ~p"/me")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", %{"me" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"me" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your details are saved")
         |> push_navigate(to: ~p"/me/profile")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
