defmodule Zippiker.HR.LeaveRequest.Validations.WithinAllowance do
  @moduledoc """
  The request can't take more days than the employee has left of the leave
  type (see `Zippiker.HR.Entitlement`); unlimited leave always passes.
  """
  use Ash.Resource.Validation

  alias Zippiker.HR.Entitlement

  @impl true
  def validate(changeset, _opts, _context) do
    record = changeset.data
    get = &(Ash.Changeset.get_attribute(changeset, &1) || Map.get(record, &1))
    opts = [tenant: changeset.tenant, authorize?: false]

    with [type_id, employee_id, %Date{} = start] <-
           [get.(:leave_type_id), get.(:employee_id), get.(:start_date)],
         true <- is_binary(type_id) and is_binary(employee_id),
         {:ok, type} <- Zippiker.HR.get_leave_type(type_id, opts),
         {:ok, employee} <- Ash.get(Zippiker.HR.Employee, employee_id, opts) do
      summary = Entitlement.summary(employee, type, start.year, opts, record.id)
      check(summary, get.(:days) || Decimal.new(0))
    else
      _ -> :ok
    end
  end

  defp check(%{left: nil}, _days), do: :ok

  defp check(%{left: left, leave_type: type, category: category}, days) do
    if Decimal.gt?(days, left) do
      when_text = if category == :fixed, do: " this year", else: ""

      {:error,
       field: :leave_type_id,
       message:
         "only #{Decimal.normalize(Decimal.max(left, 0))} #{type.name} days left#{when_text}"}
    else
      :ok
    end
  end
end
