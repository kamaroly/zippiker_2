defmodule Zippiker.HR.LeaveRequest.Validations.DatesInOrder do
  @moduledoc "The period must end on or after its start and include at least one working day."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    from = Ash.Changeset.get_attribute(changeset, :start_date)
    to = Ash.Changeset.get_attribute(changeset, :end_date)
    days = Ash.Changeset.get_attribute(changeset, :days)

    cond do
      is_nil(from) or is_nil(to) ->
        :ok

      Date.compare(to, from) == :lt ->
        {:error, field: :end_date, message: "must be on or after the start"}

      Decimal.eq?(days, 0) ->
        {:error, field: :end_date, message: "the period has no working days"}

      true ->
        :ok
    end
  end
end
