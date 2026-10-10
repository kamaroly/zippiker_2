defmodule Zippiker.Platform.BillingInvoice.Changes.FromSubscription do
  @moduledoc """
  Fills the invoice from the workspace's subscription: its current period,
  plan price and today's member count (at least one seat). Once saved, the
  subscription advances to the next period.
  """
  use Ash.Resource.Change

  alias Zippiker.Platform

  @impl true
  def change(changeset, _opts, _context) do
    organization_id = Ash.Changeset.get_argument(changeset, :organization_id)

    with {:ok, subscription} <-
           Platform.ensure_subscription(organization_id, authorize?: false),
         {:ok, organization} <-
           Ash.get(Zippiker.Accounts.Organization, organization_id,
             load: [:members_count],
             authorize?: false
           ) do
      fill(changeset, subscription, organization)
    else
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
    end
  end

  defp fill(changeset, %{status: :canceled}, _organization),
    do: Ash.Changeset.add_error(changeset, message: "the subscription is canceled")

  defp fill(changeset, subscription, organization) do
    plan = subscription.plan
    seats = max(organization.members_count, 1)
    amount = Decimal.mult(plan.price_per_seat, seats)

    if Decimal.gt?(amount, 0) do
      today = Date.utc_today()

      changeset
      |> Ash.Changeset.force_change_attributes(%{
        organization_id: organization.id,
        period_start: subscription.current_period_start,
        period_end: subscription.current_period_end,
        plan_name: plan.name,
        seats: seats,
        unit_price: plan.price_per_seat,
        amount: amount,
        currency: plan.currency,
        issued_on: today,
        due_on: Date.add(today, 14)
      })
      |> Ash.Changeset.after_action(fn _changeset, invoice ->
        with {:ok, _subscription} <-
               subscription
               |> Ash.Changeset.for_update(:advance_period, %{})
               |> Ash.update(authorize?: false) do
          {:ok, invoice}
        end
      end)
    else
      Ash.Changeset.add_error(changeset, message: "nothing to bill: #{plan.name} is free")
    end
  end
end
