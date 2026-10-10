defmodule ZippikerWeb.PartyLive.FormComponent do
  @moduledoc "Create / edit form for a contact (person) or company (organization)."
  use ZippikerWeb, :live_component

  alias Zippiker.{Extensibility, Parties}

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    kind = if socket.assigns.party, do: socket.assigns.party.kind, else: socket.assigns.kind

    {:ok,
     socket
     |> assign(:kind, kind)
     |> assign(:definitions, Extensibility.list_custom_fields!(kind, ash_opts(socket)))
     |> assign(:members, member_options(socket.assigns))
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"party" => params}, socket) do
    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, split_tags(params)))}
  end

  def handle_event("save", %{"party" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: split_tags(params)) do
      {:ok, party} ->
        send(self(), {__MODULE__, {:saved, party}})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{party: nil, kind: kind}} = socket) do
    form =
      Parties.Party
      |> AshPhoenix.Form.for_create(:create,
        as: "party",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        prepare_source: &Ash.Changeset.change_attribute(&1, :kind, kind),
        params: %{
          "owner_id" => socket.assigns.current_user.id,
          "employer_id" => socket.assigns[:employer_id]
        }
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(%{assigns: %{party: party}} = socket) do
    form =
      party
      |> AshPhoenix.Form.for_update(:update,
        as: "party",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :form, form)
  end
end
