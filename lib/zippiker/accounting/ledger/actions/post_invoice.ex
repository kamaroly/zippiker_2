defmodule Zippiker.Accounting.Ledger.Actions.PostInvoice do
  @moduledoc "Invoice issued: debit receivable (total), credit revenue (net) and tax payable (tax)."
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]
    invoice = Zippiker.Sales.get_invoice!(input.arguments.invoice_id, opts ++ [load: [:customer]])

    Posting.once(:invoice, invoice.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      total = Money.to_decimal(invoice.total)
      tax = if invoice.tax_total, do: Money.to_decimal(invoice.tax_total), else: Decimal.new(0)
      net = Decimal.sub(total, tax)
      memo = "Invoice #{invoice.number} · #{invoice.customer.name}"

      lines =
        [
          %{account_id: keys.receivable, debit: total, party_id: invoice.customer_id},
          %{account_id: keys.revenue, credit: net},
          Decimal.gt?(tax, 0) && %{account_id: keys.tax_payable, credit: tax}
        ]
        |> Enum.filter(& &1)
        |> Enum.map(&Map.put(&1, :description, memo))

      Posting.post(
        %{
          date: invoice.issued_on,
          memo: memo,
          legal_entity_id: invoice.legal_entity_id,
          branch_id: invoice.branch_id,
          source: :invoice,
          source_id: invoice.id,
          source_label: invoice.number,
          lines: lines
        },
        opts ++ [actor: context.actor]
      )
    end)
  end
end
