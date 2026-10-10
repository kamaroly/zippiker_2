defmodule ZippikerWeb.LeadLive.Show do
  @moduledoc "A lead: details, timeline, tasks and conversion."
  use ZippikerWeb, :live_view

  alias Zippiker.{Crm, Extensibility}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = ash_opts(socket)

    case Crm.get_lead(id, opts ++ [load: [:owner, :party, :company, :deal]]) do
      {:ok, lead} ->
        {:ok,
         socket
         |> assign(lead: lead, page_title: lead.name)
         |> assign(:definitions, Extensibility.list_custom_fields!(:lead, opts))
         |> assign_convert_form()}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Lead not found") |> push_navigate(to: ~p"/leads")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_convert", %{"convert" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.convert_form, params)
    {:noreply, assign(socket, convert_form: form, create_deal?: params["create_deal?"] == "true")}
  end

  def handle_event("convert", %{"convert" => params}, socket) do
    params = if params["deal_amount"] == "", do: Map.delete(params, "deal_amount"), else: params

    case AshPhoenix.Form.submit(socket.assigns.convert_form, params: params) do
      {:ok, lead} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{lead.name} converted")
         |> push_navigate(to: ~p"/contacts/#{lead.party_id}")}

      {:error, form} ->
        {:noreply, assign(socket, :convert_form, form)}
    end
  end

  @impl true
  def handle_info({ZippikerWeb.LeadLive.FormComponent, {:saved, lead}}, socket) do
    lead = Ash.load!(lead, [:owner, :party, :company, :deal], ash_opts(socket))

    {:noreply,
     socket
     |> assign(lead: lead, page_title: lead.name)
     |> assign_convert_form()
     |> put_flash(:info, "Saved")
     |> push_patch(to: ~p"/leads/#{lead}")}
  end

  defp assign_convert_form(socket) do
    form =
      socket.assigns.lead
      |> AshPhoenix.Form.for_update(:convert,
        as: "convert",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"create_deal?" => "true"}
      )
      |> to_form()

    assign(socket, convert_form: form, create_deal?: true)
  end
end
