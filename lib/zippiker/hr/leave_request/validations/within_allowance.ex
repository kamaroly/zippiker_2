defmodule Zippiker.HR.LeaveRequest.Validations.WithinAllowance do
  @moduledoc """
  The leave type must be part of the employee's leave policy, and days
  already approved or pending this year plus this request can't exceed their
  entitlement (see `Zippiker.HR.Entitlement`).
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
      entitlement = Entitlement.for(employee, type, start.year, changeset.tenant)
      check(entitlement, type, employee, start.year, get.(:days), record.id, opts)
    else
      _ -> :ok
    end
  end

  defp check(%{available?: false, policy: policy}, type, _employee, _year, _days, _id, _opts),
    do:
      {:error,
       field: :leave_type_id, message: "#{type.name} isn't part of the #{policy.name} policy"}

  defp check(%{allowance: nil}, _type, _employee, _year, _days, _id, _opts), do: :ok

  defp check(entitlement, type, employee, year, days, id, opts) do
    left =
      entitlement.allowance
      |> Decimal.add(entitlement.carried_over)
      |> Decimal.sub(Entitlement.used(employee.id, type.id, year, opts, id))

    if Decimal.gt?(days || Decimal.new(0), left),
      do:
        {:error,
         field: :leave_type_id,
         message: "only #{Decimal.normalize(left)} #{type.name} days left this year"},
      else: :ok
  end
end
