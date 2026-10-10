defmodule ZippikerWeb.AccountingLive.Journal do
  @moduledoc "Every journal entry, newest first, filterable by source."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @sources ~w(manual expense invoice payment)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Journal")}

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    source = if params["source"] in @sources, do: String.to_existing_atom(params["source"])

    page =
      Accounting.list_journal_entries!(
        %{query: query, source: source},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, source: source, page: page)
     |> stream(:entries, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: journal_path(%{q: query, source: socket.assigns.source}))}
  end

  defp journal_path(params), do: query_path(~p"/accounting/journal", params)
end
