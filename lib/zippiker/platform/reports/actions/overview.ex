defmodule Zippiker.Platform.Reports.Actions.Overview do
  @moduledoc """
  MRR counts trialing and active subscriptions at seats × price per seat,
  using each workspace's member count today (minimum one seat).
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounts.{Organization, User}
  alias Zippiker.Platform.{BillingInvoice, Subscription}

  @impl true
  def run(_input, _opts, _context) do
    opts = [authorize?: false]

    subscriptions =
      Subscription
      |> Ash.Query.load([:plan, organization: [:members_count]])
      |> Ash.read!(opts)

    open_invoices = BillingInvoice |> Ash.Query.filter(status == :open)

    {:ok,
     %{
       organizations: Ash.count!(Organization, opts),
       users: Ash.count!(User, opts),
       new_organizations_30d:
         Organization
         |> Ash.Query.filter(inserted_at >= ago(30, :day))
         |> Ash.count!(opts),
       by_status: Enum.frequencies_by(subscriptions, & &1.status),
       mrr:
         subscriptions
         |> Enum.filter(&(&1.status in [:trialing, :active]))
         |> Enum.reduce(Decimal.new(0), fn subscription, sum ->
           seats = max(subscription.organization.members_count, 1)
           Decimal.add(sum, Decimal.mult(subscription.plan.price_per_seat, seats))
         end),
       open_invoices_count: Ash.count!(open_invoices, opts),
       open_invoices_amount: Ash.sum!(open_invoices, :amount, opts) || Decimal.new(0)
     }}
  end
end
