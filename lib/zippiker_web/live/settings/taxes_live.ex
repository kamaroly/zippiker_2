defmodule ZippikerWeb.Settings.TaxesLive do
  @moduledoc "Tax rates used on products and document lines."
  use ZippikerWeb, :live_view

  alias Zippiker.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Taxes") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Catalog.TaxRate
      |> AshPhoenix.Form.for_create(:create,
        as: "tax",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, tax: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    tax = Catalog.get_tax_rate!(id, ash_opts(socket))

    form =
      tax
      |> AshPhoenix.Form.for_update(:update,
        as: "tax",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, tax: tax)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, tax: nil)

  @impl true
  def handle_event("validate", %{"tax" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"tax" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _tax} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tax rate saved")
         |> load()
         |> push_patch(to: ~p"/settings/taxes")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    id |> Catalog.get_tax_rate!(opts) |> Catalog.archive_tax_rate!(opts)
    {:noreply, socket |> put_flash(:info, "Tax rate archived") |> load()}
  end

  defp load(socket),
    do: stream(socket, :taxes, Catalog.list_tax_rates!(ash_opts(socket)), reset: true)
end
