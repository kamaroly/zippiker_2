defmodule Zippiker.HR.LeaveBalanceEntry.Validations.NonZeroDays do
  @moduledoc "An adjustment must change the balance."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :days) do
      %Decimal{} = days ->
        if Decimal.eq?(days, 0),
          do:
            {:error,
             field: :days, message: "enter days to add, or a negative number to take away"},
          else: :ok

      _ ->
        :ok
    end
  end
end
