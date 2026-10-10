defmodule ZippikerWeb.LeadLive.Index do
  @moduledoc "Lead inbox with status filters and search."
  use ZippikerWeb, :live_view

  alias Zippiker.Crm

  @statuses ~w(new contacted qualified disqualified converted all)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Leads", filters: filterable_fields(:lead, socket.assigns))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    cf = parse_custom_filters(params, socket.assigns.filters)

    status =
      if params["status"] in @statuses, do: String.to_existing_atom(params["status"]), else: nil

    page =
      Crm.list_leads!(
        %{query: query, status: status, custom_fields: cf},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, status: status, cf: cf, page: page)
     |> stream(:leads, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to: leads_path(%{q: query, status: socket.assigns.status, cf: socket.assigns.cf})
     )}
  end

  def handle_event("filter_cf", %{"cf" => cf}, socket) do
    {:noreply,
     push_patch(socket,
       to: leads_path(%{q: socket.assigns.query, status: socket.assigns.status, cf: cf})
     )}
  end

  @impl true
  def handle_info({ZippikerWeb.LeadLive.FormComponent, {:saved, lead}}, socket) do
    {:noreply, socket |> put_flash(:info, "Lead added") |> push_navigate(to: ~p"/leads/#{lead}")}
  end

  defp leads_path(params), do: query_path(~p"/leads", params)
end
