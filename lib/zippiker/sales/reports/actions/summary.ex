defmodule Zippiker.Sales.Reports.Actions.Summary do
  @moduledoc "Sales headline numbers, computed with database aggregates."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Sales.{Invoice, Payment, Quote}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, actor: context.actor]

    organization =
      Zippiker.Accounts.get_organization!(Ash.ToTenant.to_tenant(input.tenant, nil), opts)

    zero = Money.new!(organization.currency, 0)
    month_start = Date.beginning_of_month(Date.utc_today())

    open = Invoice |> Ash.Query.filter(status == :issued)
    overdue = Invoice |> Ash.Query.filter(status == :issued and due_on < today())

    invoiced =
      Invoice |> Ash.Query.filter(status in [:issued, :paid] and issued_on >= ^month_start)

    sent_quotes = Quote |> Ash.Query.filter(status == :sent)

    {:ok,
     %{
       receivable: due(open, zero, opts),
       open_count: Ash.count!(open, opts),
       overdue: due(overdue, zero, opts),
       overdue_count: Ash.count!(overdue, opts),
       invoiced_this_month: Ash.sum!(invoiced, :total, opts) || zero,
       collected_this_month:
         Payment |> Ash.Query.filter(paid_on >= ^month_start) |> Ash.sum!(:amount, opts) || zero,
       open_quotes_count: Ash.count!(sent_quotes, opts),
       open_quotes_value: Ash.sum!(sent_quotes, :total, opts) || zero
     }}
  end

  # Outstanding = invoiced total − paid so far.
  defp due(query, zero, opts) do
    total = Ash.sum!(query, :total, opts) || zero
    paid = Ash.sum!(query, :amount_paid, opts) || zero
    Money.sub!(total, paid)
  end
end
