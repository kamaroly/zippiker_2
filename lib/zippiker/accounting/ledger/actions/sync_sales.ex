defmodule Zippiker.Accounting.Ledger.Actions.SyncSales do
  @moduledoc """
  Catches the books up with sales: posts issued/paid invoices and their
  payments that were created before accounting was set up.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounting
  alias Zippiker.Sales.{Invoice, Payment}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    Accounting.setup_books!(opts)

    invoices =
      Invoice
      |> Ash.Query.filter(status in [:issued, :paid])
      |> Ash.Query.sort(issued_on: :asc)
      |> Ash.read!(opts)

    payments =
      Payment
      |> Ash.Query.filter(invoice.status in [:issued, :paid])
      |> Ash.Query.sort(paid_on: :asc)
      |> Ash.read!(opts)

    before = Ash.count!(Accounting.JournalEntry, opts)
    Enum.each(invoices, &Accounting.post_invoice!(&1.id, opts))
    Enum.each(payments, &Accounting.post_payment!(&1.id, opts))

    {:ok, %{posted: Ash.count!(Accounting.JournalEntry, opts) - before}}
  end
end
