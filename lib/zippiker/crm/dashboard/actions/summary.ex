defmodule Zippiker.Crm.Dashboard.Actions.Summary do
  @moduledoc """
  Builds the dashboard with a handful of small, indexed queries. Totals are
  computed in the database; only the last six months of won deals are
  fetched (amount and date only) to draw the revenue trend.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Crm.{Activity, Deal, Lead, Pipeline, Task}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, actor: context.actor]

    organization =
      Zippiker.Accounts.get_organization!(Ash.ToTenant.to_tenant(input.tenant, nil), opts)

    today = Date.utc_today()
    month_start = Date.beginning_of_month(today)
    zero = Money.new!(organization.currency, 0)

    stages = pipeline_stages(opts)
    open_stages = Enum.filter(stages, &(&1.kind == :open))

    {:ok,
     %{
       currency: organization.currency,
       open_value: sum_money(open_stages, zero),
       open_count: Enum.sum_by(open_stages, & &1.deals_count),
       weighted_value: weighted(open_stages, zero),
       won_this_month: won_since(month_start, opts) || zero,
       won_this_month_count: count_won_since(month_start, opts),
       win_rate: win_rate(Date.add(today, -90), opts),
       new_leads: count_leads_since(month_start, opts),
       stages: open_stages,
       revenue_trend: revenue_trend(today, organization.currency, opts),
       closing_soon: closing_soon(today, opts),
       agenda: agenda(context.actor, opts),
       recent_activity: recent_activity(opts)
     }}
  end

  defp pipeline_stages(opts) do
    Pipeline
    |> Ash.Query.sort(position: :asc, inserted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load(stages: [:deals_count, :deals_amount])
    |> Ash.read_one!(opts)
    |> case do
      nil -> []
      pipeline -> pipeline.stages
    end
  end

  defp sum_money(stages, zero) do
    Enum.reduce(stages, zero, fn stage, total -> Money.add!(total, stage.deals_amount || zero) end)
  end

  defp weighted(stages, zero) do
    Enum.reduce(stages, zero, fn stage, total ->
      Money.add!(
        total,
        Money.mult!(stage.deals_amount || zero, Decimal.div(stage.probability, 100))
      )
    end)
  end

  defp won_query(since) do
    start = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")
    Deal |> Ash.Query.filter(status == :won and closed_at >= ^start)
  end

  defp won_since(since, opts), do: since |> won_query() |> Ash.sum!(:amount, opts)
  defp count_won_since(since, opts), do: since |> won_query() |> Ash.count!(opts)

  defp win_rate(since, opts) do
    start = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")
    won = Deal |> Ash.Query.filter(status == :won and closed_at >= ^start) |> Ash.count!(opts)
    lost = Deal |> Ash.Query.filter(status == :lost and closed_at >= ^start) |> Ash.count!(opts)

    if won + lost == 0, do: nil, else: round(won * 100 / (won + lost))
  end

  defp count_leads_since(since, opts) do
    start = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")
    Lead |> Ash.Query.filter(inserted_at >= ^start) |> Ash.count!(opts)
  end

  defp revenue_trend(today, currency, opts) do
    months =
      for offset <- 5..0//-1, do: today |> Date.beginning_of_month() |> Date.shift(month: -offset)

    totals =
      months
      |> hd()
      |> won_query()
      |> Ash.Query.select([:closed_at, :amount])
      |> Ash.read!(opts)
      |> Enum.group_by(&Date.beginning_of_month(DateTime.to_date(&1.closed_at)), & &1.amount)

    Enum.map(months, fn month ->
      amount =
        totals
        |> Map.get(month, [])
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(Money.new!(currency, 0), &Money.add!/2)

      %{month: month, amount: amount}
    end)
  end

  defp closing_soon(today, opts) do
    horizon = Date.add(today, 30)

    Deal
    |> Ash.Query.filter(
      status == :open and not is_nil(expected_close_on) and expected_close_on <= ^horizon
    )
    |> Ash.Query.sort(expected_close_on: :asc)
    |> Ash.Query.limit(5)
    |> Ash.Query.load([:stage, :company, :overdue?])
    |> Ash.read!(opts)
  end

  defp agenda(actor, opts) do
    Task
    |> Ash.Query.for_read(:list, %{view: :today, assignee_id: actor.id}, opts)
    |> Ash.Query.limit(6)
    |> Ash.read!(opts)
  end

  defp recent_activity(opts) do
    Activity
    |> Ash.Query.for_read(:timeline, %{limit: 6}, opts)
    |> Ash.read!(opts)
  end
end
