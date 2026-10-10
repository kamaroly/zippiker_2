defmodule Zippiker.Sales.Invoice.Calculations.AmountDue do
  @moduledoc "Total minus payments received (zero once paid or void)."
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:total, :amount_paid, :status, :currency]

  @impl true
  def calculate(invoices, _opts, _context) do
    Enum.map(invoices, fn invoice ->
      zero = Money.new!(invoice.currency, 0)

      if invoice.status in [:void, :paid] or is_nil(invoice.total) do
        zero
      else
        Money.sub!(invoice.total, invoice.amount_paid || zero)
      end
    end)
  end
end
