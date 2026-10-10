defmodule Zippiker.Sales.Payment.Validations.FitsInvoice do
  @moduledoc "Payments go to issued invoices, in their currency, up to the amount due."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    amount = Ash.Changeset.get_attribute(changeset, :amount)
    invoice_id = Ash.Changeset.get_attribute(changeset, :invoice_id)

    with %Money{} <- amount,
         {:ok, invoice} <-
           Zippiker.Sales.get_invoice(invoice_id,
             tenant: changeset.tenant,
             authorize?: false,
             load: [:amount_due]
           ) do
      cond do
        invoice.status != :issued ->
          {:error, field: :invoice_id, message: "the invoice isn't open for payment"}

        to_string(amount.currency) != invoice.currency ->
          {:error, field: :amount, message: "must be in #{invoice.currency}"}

        not Money.positive?(amount) ->
          {:error, field: :amount, message: "must be greater than zero"}

        Money.compare!(amount, invoice.amount_due) == :gt ->
          {:error,
           field: :amount, message: "is more than the #{Money.to_string!(invoice.amount_due)} due"}

        true ->
          :ok
      end
    else
      _ -> :ok
    end
  end
end
