defmodule Zippiker.HR.Reports.Actions.Summary do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.HR.{Department, Employee, LeaveRequest}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    today = Date.utc_today()
    active = Employee |> Ash.Query.filter(status == :active)

    off_today =
      LeaveRequest
      |> Ash.Query.filter(status == :approved and start_date <= ^today and end_date >= ^today)
      |> Ash.read!(opts)
      |> Enum.uniq_by(& &1.employee_id)
      |> length()

    {:ok,
     %{
       headcount: Ash.count!(active, opts),
       new_hires_30d:
         active |> Ash.Query.filter(hire_date >= ^Date.add(today, -30)) |> Ash.count!(opts),
       off_today: off_today,
       pending_requests: LeaveRequest |> Ash.Query.filter(status == :pending) |> Ash.count!(opts),
       departments: Ash.count!(Department, opts)
     }}
  end
end
