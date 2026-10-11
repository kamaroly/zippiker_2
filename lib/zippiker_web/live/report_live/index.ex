defmodule ZippikerWeb.ReportLive.Index do
  @moduledoc "The report center: every standard report by group, with a search."
  use ZippikerWeb, :live_view

  alias Zippiker.Reporting.Catalog

  @popular ~w(profit-and-loss balance-sheet ar-ageing-summary sales-by-customer-summary)

  @impl true
  def mount(_params, _session, socket) do
    reports =
      ZippikerWeb.Access.reports(
        socket.assigns.current_organization,
        socket.assigns.current_permissions
      )

    {:ok,
     socket
     |> assign(page_title: "Reports", reports: reports, query: "")
     |> assign(:popular, Enum.filter(reports, &(&1.key in @popular)))
     |> assign_groups()}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> assign_groups()}
  end

  defp assign_groups(socket) do
    words =
      socket.assigns.query |> String.downcase() |> String.split(~r/\s+/, trim: true)

    matches =
      Enum.filter(socket.assigns.reports, fn report ->
        text = String.downcase("#{report.title} #{report.description}")
        Enum.all?(words, &String.contains?(text, &1))
      end)

    groups =
      for {key, label} <- Catalog.groups(),
          reports = Enum.filter(matches, &(key in &1.groups)),
          reports != [],
          do: %{key: key, label: label, reports: reports}

    assign(socket, groups: groups, match_count: length(matches))
  end

  defp period_label(:range), do: "Period"
  defp period_label(:as_of), do: "As of a date"
  defp period_label(:none), do: "List"
end
