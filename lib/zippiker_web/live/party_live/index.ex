defmodule ZippikerWeb.PartyLive.Index do
  @moduledoc "Directory of contacts (/contacts) or companies (/companies)."
  use ZippikerWeb, :live_view

  alias Zippiker.Parties

  @kinds %{
    contacts: :person,
    new_contact: :person,
    companies: :organization,
    new_company: :organization
  }

  # Customers (under Sales) and suppliers (under Purchasing): people and
  # companies with that role.
  @directories %{
    customers: :customer,
    new_customer: :customer,
    suppliers: :supplier,
    new_supplier: :supplier
  }

  @impl true
  def mount(_params, _session, socket) do
    directory = @directories[socket.assigns.live_action]
    kind = @kinds[socket.assigns.live_action]

    {:ok,
     assign(socket,
       directory: directory,
       kind: kind,
       filters: if(directory, do: [], else: filterable_fields(kind, socket.assigns))
     )}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{directory: role}} = socket)
      when not is_nil(role) do
    query = params["q"] || ""
    kind = parse_kind(params["type"])

    page =
      Parties.list_parties!(
        kind,
        %{query: query, role: role},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(kind: kind, query: query, role: role, cf: %{}, page: page, type: params["type"])
     |> assign(:new_kind, parse_kind(params["kind"]) || :organization)
     |> assign(:page_title, if(role == :customer, do: "Customers", else: "Suppliers"))
     |> stream(:parties, page.results, reset: true)}
  end

  def handle_params(params, _url, socket) do
    kind = @kinds[socket.assigns.live_action]
    query = params["q"] || ""
    role = parse_role(params["role"])
    cf = parse_custom_filters(params, socket.assigns.filters)

    page =
      Parties.list_parties!(
        kind,
        %{query: query, role: role, custom_fields: cf},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(kind: kind, query: query, role: role, cf: cf, page: page)
     |> assign(:page_title, if(kind == :person, do: "Contacts", else: "Companies"))
     |> stream(:parties, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, %{assigns: %{directory: role}} = socket)
      when not is_nil(role) do
    {:noreply,
     push_patch(socket, to: directory_path(role, %{q: query, type: socket.assigns.type}))}
  end

  def handle_event("search", %{"q" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         list_path(socket.assigns.kind, %{
           q: query,
           role: socket.assigns.role,
           cf: socket.assigns.cf
         })
     )}
  end

  def handle_event("filter_cf", %{"cf" => cf}, socket) do
    %{kind: kind, query: query, role: role} = socket.assigns
    {:noreply, push_patch(socket, to: list_path(kind, %{q: query, role: role, cf: cf}))}
  end

  @impl true
  def handle_info({ZippikerWeb.PartyLive.FormComponent, {:saved, party}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "#{party.name} added")
     |> push_navigate(to: show_path(party))}
  end

  defp parse_kind("person"), do: :person
  defp parse_kind("organization"), do: :organization
  defp parse_kind(_), do: nil

  defp directory_path(:customer, params), do: query_path(~p"/customers", params)
  defp directory_path(:supplier, params), do: query_path(~p"/suppliers", params)

  defp directory_new_path(:customer, kind), do: ~p"/customers/new?kind=#{kind}"
  defp directory_new_path(:supplier, kind), do: ~p"/suppliers/new?kind=#{kind}"

  defp active(%{directory: :customer}), do: :customers
  defp active(%{directory: :supplier}), do: :suppliers
  defp active(%{kind: :person}), do: :contacts
  defp active(_assigns), do: :companies

  defp parse_role(role) when role in ~w(customer lead supplier), do: String.to_existing_atom(role)
  defp parse_role(_), do: nil

  defp list_path(kind, params),
    do: query_path(if(kind == :person, do: ~p"/contacts", else: ~p"/companies"), params)

  defp new_path(:person), do: ~p"/contacts/new"
  defp new_path(:organization), do: ~p"/companies/new"

  def show_path(%{kind: :person} = party), do: ~p"/contacts/#{party}"
  def show_path(party), do: ~p"/companies/#{party}"
end
