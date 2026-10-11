defmodule Zippiker.HR.Entitlement do
  @moduledoc """
  Which leave policy applies to an employee for a leave type, and their
  balance:

    * `:fixed` — the policy's `days_per_year` each calendar year, plus the
      carry-over of last year's unused days (at most `carry_over_days`),
      plus adjustments and claims dated that year;
    * `:accrual` / `:manual` — a running balance: everything accrued,
      adjusted or claimed so far, minus all leave taken or pending;
    * `:unlimited` — no balance (`left: nil`).

  Without a policy, the leave type's own `allowance_days` works like a fixed
  allowance (empty = unlimited).
  """

  require Ash.Query

  alias Zippiker.HR.{LeaveBalanceEntry, LeavePolicy, LeavePolicyAssignment, LeaveRequest}

  @doc "The active policy for the employee and leave type: their own, else the type's default."
  def policy_for(employee_id, leave_type_id, opts) do
    assigned =
      LeavePolicyAssignment
      |> Ash.Query.filter(employee_id == ^employee_id and leave_type_id == ^leave_type_id)
      |> Ash.Query.load(:leave_policy)
      |> Ash.read_one!(opts)

    case assigned do
      %{leave_policy: %{active?: true} = policy} ->
        policy

      _ ->
        LeavePolicy
        |> Ash.Query.filter(
          leave_type_id == ^leave_type_id and default? == true and active? == true
        )
        |> Ash.read_one!(opts)
    end
  end

  @doc """
  The balance of `leave_type` for `employee` in `year`. `exclude_request_id`
  leaves one request out (when checking a request against its own balance).
  """
  def summary(employee, leave_type, year, opts, exclude_request_id \\ nil) do
    policy = policy_for(employee.id, leave_type.id, opts)
    {from, to} = {Date.new!(year, 1, 1), Date.new!(year, 12, 31)}
    usage = &used(employee.id, leave_type.id, &1, &2, opts, exclude_request_id)
    {taken, pending} = usage.(from, to)

    base = %{
      leave_type: leave_type,
      policy: policy,
      category: category(policy, leave_type),
      allowance: nil,
      carried_over: zero(),
      earned: zero(),
      taken: taken,
      pending: pending,
      left: nil
    }

    case base.category do
      :unlimited ->
        base

      :fixed ->
        allowance = if policy, do: policy.days_per_year, else: leave_type.allowance_days
        earned = entries(employee.id, leave_type.id, from, to, opts)

        if allowance do
          carried = carry_over(employee.id, leave_type.id, policy, allowance, year - 1, opts)

          %{
            base
            | allowance: allowance,
              carried_over: carried,
              earned: earned,
              left:
                allowance |> Decimal.add(carried) |> Decimal.add(earned) |> sub(taken, pending)
          }
        else
          %{base | earned: earned}
        end

      balance when balance in [:accrual, :manual] ->
        earned = entries(employee.id, leave_type.id, nil, to, opts)
        {all_taken, all_pending} = usage.(nil, to)
        %{base | earned: earned, left: sub(earned, all_taken, all_pending)}
    end
  end

  defp category(%{category: category}, _type), do: category
  defp category(nil, %{allowance_days: nil}), do: :unlimited
  defp category(nil, _type), do: :fixed

  @doc "Days of the type `{approved, pending}` with a start date in `[from, to]` (`from` nil = ever)."
  def used(employee_id, leave_type_id, from, to, opts, exclude_id \\ nil) do
    LeaveRequest
    |> Ash.Query.filter(
      employee_id == ^employee_id and leave_type_id == ^leave_type_id and
        status in [:pending, :approved] and start_date <= ^to
    )
    |> then(&if(from, do: Ash.Query.filter(&1, start_date >= ^from), else: &1))
    |> then(&if(exclude_id, do: Ash.Query.filter(&1, id != ^exclude_id), else: &1))
    |> Ash.read!(opts)
    |> Enum.reduce({zero(), zero()}, fn
      %{status: :approved, days: days}, {taken, pending} -> {Decimal.add(taken, days), pending}
      %{days: days}, {taken, pending} -> {taken, Decimal.add(pending, days)}
    end)
  end

  @doc "Sum of balance entries dated in `[from, to]` (`from` nil = ever)."
  def entries(employee_id, leave_type_id, from, to, opts) do
    LeaveBalanceEntry
    |> Ash.Query.filter(
      employee_id == ^employee_id and leave_type_id == ^leave_type_id and effective_on <= ^to
    )
    |> then(&if(from, do: Ash.Query.filter(&1, effective_on >= ^from), else: &1))
    |> Ash.sum!(:days, opts)
    |> case do
      nil -> zero()
      sum -> sum
    end
  end

  defp carry_over(_employee_id, _type_id, nil, _allowance, _year, _opts), do: zero()

  defp carry_over(employee_id, type_id, policy, allowance, last_year, opts) do
    if Decimal.gt?(policy.carry_over_days, 0) and last_year >= policy.effective_date.year do
      {from, to} = {Date.new!(last_year, 1, 1), Date.new!(last_year, 12, 31)}
      {taken, pending} = used(employee_id, type_id, from, to, opts)

      allowance
      |> Decimal.add(entries(employee_id, type_id, from, to, opts))
      |> sub(taken, pending)
      |> Decimal.max(zero())
      |> Decimal.min(policy.carry_over_days)
    else
      zero()
    end
  end

  defp sub(value, taken, pending), do: value |> Decimal.sub(taken) |> Decimal.sub(pending)
  defp zero, do: Decimal.new(0)
end
