defmodule Zippiker.Purchasing.BillPayment.Validations.FitsBill do
  @moduledoc "Payments go to approved bills, in their currency, up to the amount due."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    amount = Ash.Changeset.get_attribute(changeset, :amount)
    bill_id = Ash.Changeset.get_attribute(changeset, :bill_id)

    with %Money{} <- amount,
         {:ok, bill} <-
           Zippiker.Purchasing.get_bill(bill_id,
             tenant: changeset.tenant,
             authorize?: false,
             load: [:amount_due]
           ) do
      cond do
        bill.status != :open ->
          {:error, field: :bill_id, message: "approve the bill before paying it"}

        to_string(amount.currency) != bill.currency ->
          {:error, field: :amount, message: "must be in #{bill.currency}"}

        not Money.positive?(amount) ->
          {:error, field: :amount, message: "must be greater than zero"}

        Money.compare!(amount, bill.amount_due) == :gt ->
          {:error,
           field: :amount, message: "is more than the #{Money.to_string!(bill.amount_due)} due"}

        true ->
          :ok
      end
    else
      _ -> :ok
    end
  end
end
