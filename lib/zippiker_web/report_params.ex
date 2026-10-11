defmodule ZippikerWeb.ReportParams do
  @moduledoc """
  Turns report URL params (`period`, `from`, `to`, `branch`) into run
  arguments, shared by the report page and its CSV export. Period presets
  set both dates; "custom" keeps the dates given.
  """

  @presets [
    {"This month", "this_month"},
    {"Last month", "last_month"},
    {"This quarter", "this_quarter"},
    {"Last quarter", "last_quarter"},
    {"This year", "this_year"},
    {"Year to date", "year_to_date"},
    {"Last year", "last_year"},
    {"Last 30 days", "last_30_days"},
    {"Custom dates", "custom"}
  ]

  def presets, do: @presets

  @doc "`%{period, from, to, branch_id}` for a report's period kind."
  def parse(params, kind, branch_ids, today \\ Date.utc_today()) do
    branch = if params["branch"] in branch_ids, do: params["branch"]

    case kind do
      :range ->
        period = if params["period"] in Enum.map(@presets, &elem(&1, 1)), do: params["period"]
        period = period || if(params["from"] || params["to"], do: "custom", else: "year_to_date")
        {from, to} = range(period, params, today)
        %{period: period, from: from, to: to, branch_id: branch}

      :as_of ->
        %{period: nil, from: nil, to: date(params["to"], today), branch_id: branch}

      :none ->
        %{period: nil, from: nil, to: today, branch_id: branch}
    end
  end

  defp range("custom", params, today) do
    to = date(params["to"], today)
    from = date(params["from"], Date.new!(to.year, 1, 1))
    if Date.compare(from, to) == :gt, do: {to, from}, else: {from, to}
  end

  defp range(preset, _params, today), do: preset(preset, today)

  def preset("this_month", today), do: {Date.beginning_of_month(today), Date.end_of_month(today)}

  def preset("last_month", today) do
    last = today |> Date.beginning_of_month() |> Date.add(-1)
    {Date.beginning_of_month(last), last}
  end

  def preset("this_quarter", today), do: quarter(today)

  def preset("last_quarter", today) do
    {first, _} = quarter(today)
    quarter(Date.add(first, -1))
  end

  def preset("this_year", today), do: {Date.new!(today.year, 1, 1), Date.new!(today.year, 12, 31)}
  def preset("year_to_date", today), do: {Date.new!(today.year, 1, 1), today}

  def preset("last_year", today),
    do: {Date.new!(today.year - 1, 1, 1), Date.new!(today.year - 1, 12, 31)}

  def preset("last_30_days", today), do: {Date.add(today, -29), today}

  defp quarter(date) do
    first = Date.new!(date.year, div(date.month - 1, 3) * 3 + 1, 1)
    {first, first |> Date.shift(month: 2) |> Date.end_of_month()}
  end

  defp date(value, default) do
    case Date.from_iso8601(value || "") do
      {:ok, date} -> date
      _ -> default
    end
  end

  @doc "URL params for the current selection."
  def to_query(%{period: period, from: from, to: to, branch_id: branch}, kind) do
    case kind do
      :range when period == "custom" -> %{period: period, from: from, to: to, branch: branch}
      :range -> %{period: period, branch: branch}
      :as_of -> %{to: to, branch: branch}
      :none -> %{branch: branch}
    end
    |> Map.reject(fn {_key, value} -> value in [nil, ""] end)
  end
end
