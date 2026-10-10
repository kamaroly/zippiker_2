defmodule Zippiker.Accounting.Ledger.Actions.PostBill do
  @moduledoc """
  Bill approved. Each line debits what was bought: goods received on a PO
  clear "goods received not billed" (price differences go to cost of sales),
  other stock goes to inventory, everything else to the line's expense
  account. Tax is reclaimable input tax; the total is owed to the supplier.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounting.Ledger.{Posting, SystemAccounts}

  @impl true
  def run(input, _opts, context) do
    opts = [tenant: input.tenant, authorize?: false]

    bill =
      Zippiker.Purchasing.get_bill!(input.arguments.bill_id,
        tenant: input.tenant,
        authorize?: false,
        load: [:supplier, lines: [:product]]
      )

    Posting.once(:bill, bill.id, opts, fn ->
      keys = SystemAccounts.fetch(input.tenant)
      memo = "Bill #{bill.number} · #{bill.supplier.name}"
      tax = if bill.tax_total, do: Money.to_decimal(bill.tax_total), else: Decimal.new(0)

      debits =
        bill.lines
        |> Enum.flat_map(&debits(&1, keys))
        |> Posting.net_by_account()

      lines =
        Posting.lines(debits, memo) ++
          if(Decimal.gt?(tax, 0),
            do: [%{account_id: keys.tax_receivable, debit: tax, description: memo}],
            else: []
          ) ++
          [
            %{
              account_id: keys.payable,
              credit: Money.to_decimal(bill.total),
              party_id: bill.supplier_id,
              description: memo
            }
          ]

      Posting.post(
        %{
          date: bill.issued_on,
          memo: memo,
          legal_entity_id: bill.legal_entity_id,
          source: :bill,
          source_id: bill.id,
          source_label: bill.number,
          lines: lines
        },
        opts ++ [actor: context.actor]
      )
    end)
  end

  defp debits(%{received_unit_cost: %Decimal{} = cost} = line, keys) do
    received = line.quantity |> Decimal.mult(cost) |> Decimal.round(2)
    [{keys.grni, received}, {keys.cost_of_sales, Decimal.sub(line.subtotal, received)}]
  end

  defp debits(%{product: %{track_inventory?: true}} = line, keys),
    do: [{keys.inventory, line.subtotal}]

  defp debits(line, keys), do: [{line.expense_account_id || keys.expense, line.subtotal}]
end
