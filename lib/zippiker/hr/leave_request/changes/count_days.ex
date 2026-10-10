defmodule Zippiker.HR.LeaveRequest.Changes.CountDays do
  @moduledoc "Sets `days` to the working days between the dates."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    days =
      Zippiker.HR.WorkingDays.count(
        Ash.Changeset.get_attribute(changeset, :start_date),
        Ash.Changeset.get_attribute(changeset, :end_date)
      )

    Ash.Changeset.force_change_attribute(changeset, :days, Decimal.new(days))
  end
end
