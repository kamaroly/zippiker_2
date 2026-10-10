defmodule Zippiker.HR.WorkingDays do
  @moduledoc "Counts Monday–Friday days in a date range (public holidays aren't modelled yet)."

  @doc "Working days from `from` to `to`, inclusive. 0 when `to` is before `from`."
  def count(%Date{} = from, %Date{} = to) do
    if Date.compare(to, from) == :lt do
      0
    else
      Date.range(from, to) |> Enum.count(&(Date.day_of_week(&1) in 1..5))
    end
  end

  def count(_from, _to), do: 0
end
