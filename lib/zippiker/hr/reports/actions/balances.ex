defmodule Zippiker.HR.Reports.Actions.Balances do
  @moduledoc "One balance per active leave type for the employee (see `Zippiker.HR.Entitlement`)."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.HR.{Entitlement, LeaveType}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    year = input.arguments[:year] || Date.utc_today().year
    employee = Ash.get!(Zippiker.HR.Employee, input.arguments.employee_id, opts)

    types =
      LeaveType
      |> Ash.Query.filter(active? == true)
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(opts)

    {:ok, Enum.map(types, &Entitlement.summary(employee, &1, year, opts))}
  end
end
