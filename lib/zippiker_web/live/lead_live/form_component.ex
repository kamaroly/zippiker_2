defmodule ZippikerWeb.LeadLive.FormComponent do
  @moduledoc "Create / edit form for a lead."
  use ZippikerWeb, :live_component

  alias Zippiker.{Crm, Extensibility}

  @sources ~w(website referral event cold_outreach social advertising other)a
  @statuses ~w(new contacted qualified disqualified)a

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     socket
     |> assign(:definitions, Extensibility.list_custom_fields!(:lead, ash_opts(socket)))
     |> assign(:members, member_options(socket.assigns))
     |> assign(:sources, Enum.map(@sources, &{Format.humanize(&1), &1}))
     |> assign(:statuses, Enum.map(@statuses, &{Format.humanize(&1), &1}))
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"lead" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"lead" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, lead} ->
        send(self(), {__MODULE__, {:saved, lead}})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{lead: nil}} = socket) do
    form =
      Crm.Lead
      |> AshPhoenix.Form.for_create(:create,
        as: "lead",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"owner_id" => socket.assigns.current_user.id}
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(%{assigns: %{lead: lead}} = socket) do
    form =
      lead
      |> AshPhoenix.Form.for_update(:update,
        as: "lead",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :form, form)
  end
end
