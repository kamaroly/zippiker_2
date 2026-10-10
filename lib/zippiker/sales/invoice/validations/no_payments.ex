defmodule Zippiker.Sales.Invoice.Validations.NoPayments do
  @moduledoc "Invoices with payments can't be voided; delete the payments first."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    paid = changeset.data.amount_paid

    if paid && Money.positive?(paid),
      do: {:error, message: "remove its payments before voiding"},
      else: :ok
  end
end
