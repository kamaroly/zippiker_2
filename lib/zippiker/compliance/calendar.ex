defmodule Zippiker.Compliance.Calendar do
  @moduledoc """
  Recurring statutory obligations for a company, created once per period:

    * the annual return, due 30 days after each anniversary of
      incorporation (this year's and next year's);
    * for public companies, the AGM within 6 months after the financial
      year end.

  Event-driven filings (director changes, allotments…) are added by
  `Zippiker.Compliance.Changes.AddFiling`. These are sensible defaults;
  confirm deadlines with your company secretary.
  """

  alias Zippiker.Compliance.ComplianceTask

  def refresh(profile, tenant, today \\ Date.utc_today()) do
    opts = [tenant: tenant, authorize?: false]

    tasks = annual_returns(profile, today) ++ agms(profile, today)

    Enum.each(tasks, fn task ->
      ComplianceTask
      |> Ash.Changeset.for_create(:create, Map.put(task, :profile_id, profile.id), opts)
      |> Ash.create!(upsert?: true, upsert_identity: :one_per_period, upsert_fields: [])
    end)

    length(tasks)
  end

  defp annual_returns(%{incorporation_date: %Date{} = incorporated}, today) do
    for year <- [today.year, today.year + 1], year > incorporated.year do
      anniversary = anniversary(incorporated, year)

      %{
        kind: :annual_return,
        title: "Annual return #{year}",
        description:
          "File the annual return with the Registrar of Companies (made up to the anniversary of incorporation, #{Calendar.strftime(anniversary, "%-d %b %Y")}).",
        due_on: Date.add(anniversary, 30),
        period: "AR-#{year}"
      }
    end
  end

  defp annual_returns(_profile, _today), do: []

  defp agms(%{company_type: :public_limited} = profile, today) do
    for year <- [today.year - 1, today.year] do
      year_end = year_end(profile, year)

      %{
        kind: :agm,
        title: "Annual general meeting (year ended #{Calendar.strftime(year_end, "%-d %b %Y")})",
        description:
          "Hold the AGM within six months after the financial year end, with proper notice to members.",
        due_on: Date.shift(year_end, month: 6),
        period: "AGM-#{year}"
      }
    end
  end

  defp agms(_profile, _today), do: []

  defp anniversary(date, year) do
    case Date.new(year, date.month, date.day) do
      {:ok, day} -> day
      _ -> Date.new!(year, date.month, 28)
    end
  end

  defp year_end(profile, year) do
    day =
      min(profile.year_end_day, Date.days_in_month(Date.new!(year, profile.year_end_month, 1)))

    Date.new!(year, profile.year_end_month, day)
  end
end
