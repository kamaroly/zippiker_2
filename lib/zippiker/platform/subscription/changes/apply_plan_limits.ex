defmodule Zippiker.Platform.Subscription.Changes.ApplyPlanLimits do
  @moduledoc """
  When the plan is set or changed, copies its modules and seat limit onto the
  workspace. Super admins can still fine-tune them afterwards.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :plan_id) do
      Ash.Changeset.after_action(changeset, fn _changeset, subscription ->
        plan = Ash.get!(Zippiker.Platform.Plan, subscription.plan_id, authorize?: false)

        organization =
          Ash.get!(Zippiker.Accounts.Organization, subscription.organization_id,
            authorize?: false
          )

        with {:ok, _organization} <-
               Zippiker.Accounts.set_plan_limits(
                 organization,
                 %{enabled_modules: plan.modules, seat_limit: plan.seat_limit},
                 authorize?: false
               ) do
          {:ok, subscription}
        end
      end)
    else
      changeset
    end
  end
end
