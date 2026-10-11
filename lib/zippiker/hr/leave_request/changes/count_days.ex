defmodule Zippiker.HR.LeaveRequest.Changes.CountDays do
  @moduledoc """
  Sets `days`: working days (Mon–Fri, minus public holidays) between the
  dates, or every calendar day when the employee's leave policy counts
  weekends and holidays.
  """
  use Ash.Resource.Change

  alias Zippiker.HR.{Entitlement, WorkingDays}

  @impl true
  def change(changeset, _opts, _context) do
    from = Ash.Changeset.get_attribute(changeset, :start_date)
    to = Ash.Changeset.get_attribute(changeset, :end_date)
    opts = [tenant: changeset.tenant, authorize?: false]

    days =
      if count_everything?(changeset, opts),
        do: WorkingDays.calendar_days(from, to),
        else: WorkingDays.count(from, to, WorkingDays.holidays(from, to, opts))

    Ash.Changeset.force_change_attribute(changeset, :days, Decimal.new(days))
  end

  defp count_everything?(changeset, opts) do
    employee_id = Ash.Changeset.get_attribute(changeset, :employee_id)
    type_id = Ash.Changeset.get_attribute(changeset, :leave_type_id)

    match?(
      %{count_weekends_and_holidays?: true},
      employee_id && type_id && Entitlement.policy_for(employee_id, type_id, opts)
    )
  end
end
