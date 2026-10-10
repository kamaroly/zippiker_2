defmodule Zippiker.Platform.Subscription.Changes.StartPeriod do
  @moduledoc "First billing period starts today; trialing when the plan has trial days."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    plan_id = Ash.Changeset.get_attribute(changeset, :plan_id)
    plan = Ash.get!(Zippiker.Platform.Plan, plan_id, authorize?: false)
    today = Date.utc_today()

    {status, trial_ends_on} =
      if plan.trial_days > 0,
        do: {:trialing, Date.add(today, plan.trial_days)},
        else: {:active, nil}

    Ash.Changeset.force_change_attributes(changeset, %{
      status: status,
      trial_ends_on: trial_ends_on,
      current_period_start: today,
      current_period_end: Zippiker.Platform.Subscription.Changes.AdvancePeriod.period_end(today)
    })
  end
end
