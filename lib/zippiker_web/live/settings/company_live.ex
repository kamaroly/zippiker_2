defmodule ZippikerWeb.Settings.CompanyLive do
  @moduledoc "Legal entities: the companies that issue quotes and invoices."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts
  alias Zippiker.Accounts.LegalEntity

  @impl true
  def mount(_params, _session, socket) do
    # Ensures the default entity exists for workspaces created before it did.
    Accounts.default_legal_entity!(ash_opts(socket))
    {:ok, socket |> assign(:page_title, "Company details") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    entity =
      case socket.assigns.live_action do
        :new -> nil
        :edit -> Enum.find(socket.assigns.entities, &(&1.id == params["id"]))
        :index -> List.first(socket.assigns.entities)
      end

    {:noreply, socket |> assign(:entity, entity) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"entity" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"entity" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, entity} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{entity.name} saved")
         |> load()
         |> push_patch(to: ~p"/settings/company/#{entity}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{entity: nil}} = socket) do
    form =
      LegalEntity
      |> AshPhoenix.Form.for_create(:create,
        as: "entity",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"currency" => socket.assigns.current_organization.currency}
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(%{assigns: %{entity: entity}} = socket) do
    form =
      entity
      |> AshPhoenix.Form.for_update(:update,
        as: "entity",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp load(socket),
    do: assign(socket, :entities, Accounts.list_legal_entities!(ash_opts(socket)))
end
