defmodule ZippikerWeb.Format do
  @moduledoc "Presentation helpers shared by templates."

  @doc "`$12,500` style money. Whole amounts drop the cents."
  def money(nil), do: "—"

  def money(%Money{} = money) do
    fractional_digits = if Decimal.integer?(Money.round(money).amount), do: 0, else: 2
    Money.to_string!(money, fractional_digits: fractional_digits)
  end

  @doc "Compact money for charts and KPI tiles: `$12.5K`, `$1.2M`."
  def money_short(nil), do: "—"

  def money_short(%Money{} = money) do
    case Money.to_string(money, format: :short) do
      {:ok, string} -> string
      _ -> money(money)
    end
  end

  def date(nil), do: "—"
  def date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")
  def date(%DateTime{} = datetime), do: datetime |> DateTime.to_date() |> date()

  @doc "Relative day label for due dates: Today, Tomorrow, Yesterday, Mar 3."
  def due(nil), do: nil

  def due(%Date{} = date) do
    case Date.diff(date, Date.utc_today()) do
      0 -> "Today"
      1 -> "Tomorrow"
      -1 -> "Yesterday"
      diff when diff in 2..6 -> Calendar.strftime(date, "%A")
      _ -> Calendar.strftime(date, "%b %-d")
    end
  end

  @doc "Human time ago: `just now`, `5m ago`, `3h ago`, `Mar 3`."
  def ago(%DateTime{} = datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      seconds < 7 * 86_400 -> "#{div(seconds, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%b %-d")
    end
  end

  @doc "`cold_outreach` -> `Cold outreach`."
  def humanize(nil), do: ""
  def humanize(value), do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  @doc "`1 deal`, `3 deals`."
  def count(1, noun), do: "1 #{noun}"
  def count(n, noun), do: "#{n} #{noun}s"

  @doc "Time-of-day greeting."
  def greeting(%DateTime{hour: hour}) when hour < 12, do: "Good morning"
  def greeting(%DateTime{hour: hour}) when hour < 18, do: "Good afternoon"
  def greeting(_), do: "Good evening"

  def first_name(%{name: name}) when is_binary(name) and name != "",
    do: name |> String.split() |> hd()

  def first_name(%{email: email}), do: email |> to_string() |> String.split("@") |> hd()
  def first_name(_), do: "there"

  def user_name(nil), do: "Unassigned"
  def user_name(%{name: name}) when is_binary(name) and name != "", do: name
  def user_name(%{email: email}), do: to_string(email)
end
