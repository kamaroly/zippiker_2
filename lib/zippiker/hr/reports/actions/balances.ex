defmodule Zippiker.HR.Reports.Actions.Balances do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.HR.{Entitlement, LeaveRequest, LeaveType}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    year = input.arguments[:year] || Date.utc_today().year
    employee = Ash.get!(Zippiker.HR.Employee, input.arguments.employee_id, opts)
    {from, to} = {Date.new!(year, 1, 1), Date.new!(year, 12, 31)}

    requests =
      LeaveRequest
      |> Ash.Query.filter(
        employee_id == ^employee.id and status in [:pending, :approved] and
          start_date >= ^from and start_date <= ^to
      )
      |> Ash.read!(opts)

    types =
      LeaveType
      |> Ash.Query.filter(active? == true)
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(opts)

    {:ok,
     for type <- types,
         entitlement = Entitlement.for(employee, type, year, input.tenant),
         entitlement.available? do
       mine = Enum.filter(requests, &(&1.leave_type_id == type.id))
       taken = sum(mine, :approved)
       pending = sum(mine, :pending)

       %{
         leave_type: type,
         policy: entitlement.policy,
         allowance: entitlement.allowance,
         carried_over: entitlement.carried_over,
         taken: taken,
         pending: pending,
         left:
           entitlement.allowance &&
             entitlement.allowance
             |> Decimal.add(entitlement.carried_over)
             |> Decimal.sub(taken)
             |> Decimal.sub(pending)
       }
     end}
  end

  defp sum(requests, status) do
    requests
    |> Enum.filter(&(&1.status == status))
    |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.days))
  end
end
