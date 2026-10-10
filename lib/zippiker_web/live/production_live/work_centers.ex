defmodule ZippikerWeb.ProductionLive.WorkCenters do
  @moduledoc "Work centers: where operations happen and what an hour there costs."
  use ZippikerWeb, :live_view

  alias Zippiker.Manufacturing

  @impl true
  def mount(_params, _session, socket) do
    currency = Zippiker.Accounts.default_legal_entity!(ash_opts(socket)).currency
    {:ok, socket |> assign(page_title: "Work centers", currency: currency) |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Manufacturing.WorkCenter
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> to_form()

    assign(socket, form: form, work_center: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    work_center = Manufacturing.get_work_center!(id, ash_opts(socket))

    form =
      work_center
      |> AshPhoenix.Form.for_update(:update, form_opts(socket))
      |> to_form()

    assign(socket, form: form, work_center: work_center)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, work_center: nil)

  defp form_opts(socket) do
    [
      as: "work_center",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]
  end

  @impl true
  def handle_event("validate", %{"work_center" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"work_center" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _work_center} ->
        {:noreply,
         socket
         |> put_flash(:info, "Work center saved")
         |> load()
         |> push_patch(to: ~p"/manufacturing/work-centers")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    work_center = Manufacturing.get_work_center!(id, ash_opts(socket))

    case Manufacturing.delete_work_center(work_center, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Work center deleted") |> load()}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Bills of materials use this work center; deactivate it instead"
         )}
    end
  end

  defp load(socket),
    do:
      stream(socket, :work_centers, Manufacturing.list_work_centers!(ash_opts(socket)),
        reset: true
      )
end
