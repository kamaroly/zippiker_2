defmodule Zippiker.Expenses.ExpenseClaim.Validations.HasItems do
  @moduledoc "A claim needs at least one expense with an amount before it's submitted."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    total = changeset.data.total

    if total && Decimal.gt?(Money.to_decimal(total), 0),
      do: :ok,
      else: {:error, field: :total, message: "add at least one expense before submitting"}
  end
end
