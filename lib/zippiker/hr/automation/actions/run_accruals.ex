defmodule Zippiker.HR.Automation.Actions.RunAccruals do
  @moduledoc """
  For each active accrual policy and each active employee it covers
  (assigned, or everyone without their own policy when it's the type's
  default): credits `accrual_days` on the first day of every period from
  the later of the policy's effective date and the hire date, up to
  `as_of`. Periods already credited are skipped; a period that would take
  the balance over `accrual_cap` credits only up to the cap (possibly 0),
  so it isn't retried later.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.HR.{Employee, Entitlement, LeaveBalanceEntry, LeavePolicy, LeavePolicyAssignment}

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    as_of = input.arguments[:as_of] || Date.utc_today()

    credited =
      LeavePolicy
      |> Ash.Query.filter(category == :accrual and active? == true and effective_date <= ^as_of)
      |> Ash.Query.load(:leave_type)
      |> Ash.read!(opts)
      |> Enum.map(fn policy ->
        policy
        |> employees(opts)
        |> Enum.map(&accrue(policy, &1, as_of, opts))
        |> Enum.sum()
      end)
      |> Enum.sum()

    {:ok, %{credited: credited, as_of: as_of}}
  end

  defp employees(policy, opts) do
    assigned =
      LeavePolicyAssignment
      |> Ash.Query.filter(leave_type_id == ^policy.leave_type_id)
      |> Ash.read!(opts)

    on_policy =
      for a <- assigned, a.leave_policy_id == policy.id, into: MapSet.new(), do: a.employee_id

    with_own = MapSet.new(assigned, & &1.employee_id)

    Employee
    |> Ash.Query.filter(status == :active)
    |> Ash.read!(opts)
    |> Enum.filter(fn employee ->
      MapSet.member?(on_policy, employee.id) or
        (policy.default? and not MapSet.member?(with_own, employee.id))
    end)
  end

  # Credits the missing periods for one employee; returns how many entries it wrote.
  defp accrue(policy, employee, as_of, opts) do
    start = later(policy.effective_date, employee.hire_date)

    done =
      LeaveBalanceEntry
      |> Ash.Query.filter(
        employee_id == ^employee.id and leave_policy_id == ^policy.id and kind == :accrual
      )
      |> Ash.read!(opts)
      |> MapSet.new(& &1.period)

    start
    |> period_starts(as_of, policy.accrual_frequency)
    |> Enum.reject(&MapSet.member?(done, period_key(&1, policy.accrual_frequency)))
    |> Enum.map(fn day ->
      days = capped(policy, employee, day, opts)

      LeaveBalanceEntry
      |> Ash.Changeset.for_create(
        :record,
        %{
          kind: :accrual,
          employee_id: employee.id,
          leave_type_id: policy.leave_type_id,
          leave_policy_id: policy.id,
          days: days,
          effective_on: day,
          period: period_key(day, policy.accrual_frequency),
          note:
            if(Decimal.lt?(days, policy.accrual_days),
              do: "#{policy.name}: capped at #{Decimal.normalize(policy.accrual_cap)} days",
              else: policy.name
            )
        },
        opts
      )
      |> Ash.create!(authorize?: false, upsert?: true, upsert_identity: :one_accrual_per_period)
    end)
    |> length()
  end

  defp capped(%{accrual_cap: nil} = policy, _employee, _day, _opts), do: policy.accrual_days

  defp capped(policy, employee, day, opts) do
    balance =
      Entitlement.summary(employee, policy.leave_type, day.year, opts).left || Decimal.new(0)

    room = Decimal.sub(policy.accrual_cap, balance)

    room
    |> Decimal.max(Decimal.new(0))
    |> Decimal.min(policy.accrual_days)
  end

  defp later(date, nil), do: date
  defp later(date, other), do: if(Date.compare(other, date) == :gt, do: other, else: date)

  @doc false
  # First day of every period that starts within [from, to].
  def period_starts(from, to, frequency) do
    from
    |> first_period_start(frequency)
    |> Stream.iterate(&next(&1, frequency))
    |> Stream.take_while(&(Date.compare(&1, to) != :gt))
    |> Enum.filter(&(Date.compare(&1, from) != :lt))
  end

  defp first_period_start(date, :weekly), do: Date.beginning_of_week(date)
  defp first_period_start(date, :monthly), do: Date.beginning_of_month(date)

  defp first_period_start(date, :quarterly),
    do: Date.new!(date.year, div(date.month - 1, 3) * 3 + 1, 1)

  defp first_period_start(date, :yearly), do: Date.new!(date.year, 1, 1)

  defp next(date, :weekly), do: Date.add(date, 7)
  defp next(date, :monthly), do: Date.shift(date, month: 1)
  defp next(date, :quarterly), do: Date.shift(date, month: 3)
  defp next(date, :yearly), do: Date.shift(date, year: 1)

  @doc false
  def period_key(date, :weekly) do
    {year, week} = :calendar.iso_week_number(Date.to_erl(date))
    "W#{year}-#{String.pad_leading("#{week}", 2, "0")}"
  end

  def period_key(date, :monthly),
    do: "M#{date.year}-#{String.pad_leading("#{date.month}", 2, "0")}"

  def period_key(date, :quarterly), do: "Q#{date.year}-#{div(date.month - 1, 3) + 1}"
  def period_key(date, :yearly), do: "Y#{date.year}"
end
