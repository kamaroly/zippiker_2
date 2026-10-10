defmodule ZippikerWeb.DealLive.FormComponent do
  @moduledoc "Create / edit form for a deal."
  use ZippikerWeb, :live_component

  alias Zippiker.{Crm, Extensibility}

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    opts = ash_opts(socket)

    stages =
      opts
      |> Crm.list_pipelines!()
      |> Enum.flat_map(fn pipeline ->
        Enum.map(pipeline.stages, &{"#{pipeline.name} · #{&1.name}", &1.id})
      end)

    {:ok,
     socket
     |> assign(:definitions, Extensibility.list_custom_fields!(:deal, opts))
     |> assign(:members, member_options(socket.assigns))
     |> assign(:stages, stages)
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"deal" => params}, socket) do
    params = put_money(params, "amount", socket.assigns.current_organization)
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"deal" => params}, socket) do
    params = put_money(params, "amount", socket.assigns.current_organization)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, deal} ->
        send(self(), {__MODULE__, {:saved, deal}})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{deal: nil}} = socket) do
    defaults =
      Map.merge(
        %{"owner_id" => socket.assigns.current_user.id, "stage_id" => socket.assigns[:stage_id]},
        socket.assigns[:defaults] || %{}
      )

    form =
      Crm.Deal
      |> AshPhoenix.Form.for_create(:create,
        as: "deal",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: defaults
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp assign_form(%{assigns: %{deal: deal}} = socket) do
    form =
      deal
      |> AshPhoenix.Form.for_update(:update,
        as: "deal",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :form, form)
  end
end
