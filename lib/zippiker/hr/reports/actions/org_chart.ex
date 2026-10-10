defmodule Zippiker.HR.Reports.Actions.OrgChart do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    employees =
      Zippiker.HR.Employee
      |> Ash.Query.filter(status == :active)
      |> Ash.Query.load([:name, :on_leave_today?, :department])
      |> Ash.Query.sort(hire_date: :asc)
      |> Ash.read!(tenant: input.tenant, authorize?: false)

    ids = MapSet.new(employees, & &1.id)
    by_manager = Enum.group_by(employees, & &1.manager_id)

    # Top level: no manager, or a manager who left.
    roots = Enum.filter(employees, &(is_nil(&1.manager_id) or &1.manager_id not in ids))
    {:ok, Enum.map(roots, &node(&1, by_manager, 0))}
  end

  defp node(employee, by_manager, depth) do
    reports =
      if depth > 30,
        do: [],
        else: Enum.map(Map.get(by_manager, employee.id, []), &node(&1, by_manager, depth + 1))

    %{employee: employee, reports: reports}
  end
end
