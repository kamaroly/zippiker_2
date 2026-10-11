defmodule ZippikerWeb.ReportLive.Show do
  @moduledoc "Runs one standard report with period and branch filters, print and CSV export."
  use ZippikerWeb, :live_view

  alias Zippiker.Reporting
  alias Zippiker.Reporting.Catalog
  alias ZippikerWeb.ReportParams

  @impl true
  def mount(%{"key" => key}, _session, socket) do
    organization = socket.assigns.current_organization

    case Enum.find(Catalog.available(organization), &(&1.key == key)) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That report isn't available in this workspace.")
         |> push_navigate(to: ~p"/reports")}

      definition ->
        {:ok,
         assign(socket,
           definition: definition,
           page_title: definition.title,
           branch_options: branch_options(socket.assigns),
           presets: ReportParams.presets()
         )}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    definition = socket.assigns.definition
    branch_ids = Enum.map(socket.assigns.branch_options, &elem(&1, 1))
    selection = ReportParams.parse(params, definition.period, branch_ids)

    report =
      Reporting.run_report!(
        definition.key,
        %{from: selection.from, to: selection.to, branch_id: selection.branch_id},
        ash_opts(socket)
      )

    {:noreply,
     assign(socket,
       selection: selection,
       report: report,
       generated_at: DateTime.utc_now(),
       branch_name:
         Enum.find_value(socket.assigns.branch_options, fn {name, id} ->
           id == selection.branch_id && name
         end)
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    period = socket.assigns.definition.period

    # Typing a date switches the period to custom dates.
    params =
      if period == :range and params["_target"] in [["from"], ["to"]],
        do: Map.put(params, "period", "custom"),
        else: params

    branch_ids = Enum.map(socket.assigns.branch_options, &elem(&1, 1))
    selection = ReportParams.parse(params, period, branch_ids)
    {:noreply, push_patch(socket, to: report_path(socket.assigns.definition, selection))}
  end

  defp report_path(definition, selection) do
    query_path(
      ~p"/reports/#{definition.key}",
      ReportParams.to_query(selection, definition.period)
    )
  end

  defp export_path(definition, selection) do
    query_path(
      ~p"/reports/#{definition.key}/export",
      ReportParams.to_query(%{selection | period: "custom"}, definition.period)
      |> Map.merge(if(selection.from, do: %{from: selection.from}, else: %{}))
    )
  end

  defp period_text(%{period: :range}, selection),
    do: "#{Format.date(selection.from)} – #{Format.date(selection.to)}"

  defp period_text(%{period: :as_of}, selection), do: "As of #{Format.date(selection.to)}"
  defp period_text(%{period: :none}, _selection), do: "As of today"
end
