defmodule ZippikerWeb.Settings.WorkspaceLive do
  @moduledoc "Workspace name and maker-checker. People are under Settings → Users."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts

  @impl true
  def mount(_params, _session, socket) do
    organization = socket.assigns.current_organization

    form =
      organization
      |> AshPhoenix.Form.for_update(:update, as: "workspace", actor: socket.assigns.current_user)
      |> to_form()

    {:ok,
     socket
     |> assign(page_title: "Workspace", form: form)
     |> assign(:admin_count, admin_count(socket))}
  end

  @impl true
  def handle_event("validate", %{"workspace" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"workspace" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: Map.take(params, ["name"])) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> assign(:current_organization, organization)
         |> put_flash(:info, "Workspace saved")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("save_maker_checker", %{"maker_checker" => params}, socket) do
    scopes = params |> Map.get("scopes", []) |> Enum.reject(&(&1 == ""))

    case Accounts.set_maker_checker(
           socket.assigns.current_organization,
           %{maker_checker?: params["enabled"] == "true", maker_checker_scopes: scopes},
           actor: socket.assigns.current_user
         ) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> assign(:current_organization, organization)
         |> put_flash(:info, "Maker-checker settings saved")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp admin_count(socket) do
    socket.assigns.current_organization.id
    |> Accounts.list_members!(actor: socket.assigns.current_user)
    |> Enum.count(&(&1.role in [:owner, :admin]))
  end
end
