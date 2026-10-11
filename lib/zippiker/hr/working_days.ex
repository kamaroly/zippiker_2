defmodule Zippiker.HR.WorkingDays do
  @moduledoc """
  Counts leave days in a date range: Monday–Friday excluding the
  workspace's public holidays, or every calendar day when the leave policy
  counts weekends and holidays.
  """

  require Ash.Query

  @doc "Working days from `from` to `to`, inclusive, skipping `holidays` (a list of dates)."
  def count(from, to, holidays \\ [])

  def count(%Date{} = from, %Date{} = to, holidays) do
    if Date.compare(to, from) == :lt do
      0
    else
      skip = MapSet.new(holidays)

      Date.range(from, to)
      |> Enum.count(&(Date.day_of_week(&1) in 1..5 and not MapSet.member?(skip, &1)))
    end
  end

  def count(_from, _to, _holidays), do: 0

  @doc "Every day from `from` to `to`, inclusive."
  def calendar_days(%Date{} = from, %Date{} = to),
    do: max(Date.diff(to, from) + 1, 0)

  def calendar_days(_from, _to), do: 0

  @doc "The workspace's holiday dates between `from` and `to` (recurring ones every year)."
  def holidays(%Date{} = from, %Date{} = to, opts) do
    Zippiker.HR.Holiday
    |> Ash.read!(opts)
    |> Enum.flat_map(fn
      %{recurring?: true, date: date} ->
        for year <- from.year..to.year//1,
            {:ok, day} <- [Date.new(year, date.month, date.day)],
            do: day

      %{date: date} ->
        [date]
    end)
    |> Enum.filter(&(Date.compare(&1, from) != :lt and Date.compare(&1, to) != :gt))
  end

  def holidays(_from, _to, _opts), do: []
end
