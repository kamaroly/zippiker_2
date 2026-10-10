defmodule Zippiker.Purchasing.Reports.Actions.Summary do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Purchasing.{Bill, PurchaseOrder}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, actor: context.actor]

    organization =
      Zippiker.Accounts.get_organization!(Ash.ToTenant.to_tenant(input.tenant, nil), opts)

    zero = Money.new!(organization.currency, 0)
    week = Date.add(Date.utc_today(), 7)

    open = Bill |> Ash.Query.filter(status == :open)
    overdue = Bill |> Ash.Query.filter(status == :open and due_on < today())
    due_soon = Bill |> Ash.Query.filter(status == :open and due_on >= today() and due_on <= ^week)
    to_receive = PurchaseOrder |> Ash.Query.filter(status in [:ordered, :partially_received])

    {:ok,
     %{
       payable: due(open, zero, opts),
       open_count: Ash.count!(open, opts),
       overdue: due(overdue, zero, opts),
       overdue_count: Ash.count!(overdue, opts),
       due_this_week: due(due_soon, zero, opts),
       orders_to_receive: Ash.count!(to_receive, opts),
       orders_to_receive_value: Ash.sum!(to_receive, :total, opts) || zero
     }}
  end

  defp due(query, zero, opts) do
    total = Ash.sum!(query, :total, opts) || zero
    paid = Ash.sum!(query, :amount_paid, opts) || zero
    Money.sub!(total, paid)
  end
end
