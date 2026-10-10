defmodule ZippikerWeb.Components.PartyPicker do
  @moduledoc """
  Searchable contact/company picker that submits the chosen id under `name`
  as part of the surrounding form.

      <.live_component module={PartyPicker} id="deal-company" name={@form[:company_id].name}
        value={@form[:company_id].value} kind={:organization} label="Company"
        current_user={@current_user} current_organization={@current_organization} />

  `kind` is `:person`, `:organization` or `nil` for both.
  """
  use ZippikerWeb, :live_component

  alias Zippiker.Parties

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:kind, fn -> nil end)
      |> assign_new(:placeholder, fn -> "Search…" end)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:results, fn -> [] end)
      |> assign_new(:query, fn -> "" end)

    {:ok, assign_selected(socket, assigns[:value])}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    {:noreply, assign(socket, query: query, results: search(socket, query))}
  end

  def handle_event("pick", %{"id" => id}, socket) do
    party = Enum.find(socket.assigns.results, &(&1.id == id))
    {:noreply, assign(socket, selected: party, results: [], query: "")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, selected: nil, results: [], query: "")}
  end

  defp assign_selected(socket, value) when value in [nil, ""] do
    if Map.has_key?(socket.assigns, :selected), do: socket, else: assign(socket, :selected, nil)
  end

  defp assign_selected(socket, value) do
    case socket.assigns[:selected] do
      %{id: ^value} ->
        socket

      _ ->
        case Parties.get_party(value, ash_opts(socket.assigns)) do
          {:ok, party} -> assign(socket, :selected, party)
          _ -> assign(socket, :selected, nil)
        end
    end
  end

  defp search(_socket, query) when byte_size(query) < 1, do: []

  defp search(socket, query) do
    kinds = if socket.assigns.kind, do: [socket.assigns.kind], else: [:organization, :person]
    limit = if length(kinds) == 1, do: 8, else: 5

    Enum.flat_map(kinds, fn kind ->
      Parties.list_parties!(
        kind,
        %{query: query},
        ash_opts(socket.assigns) ++ [page: [limit: limit]]
      ).results
    end)
  end
end
