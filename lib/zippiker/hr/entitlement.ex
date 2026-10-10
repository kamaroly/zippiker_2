defmodule Zippiker.HR.Entitlement do
  @moduledoc """
  How many days of a leave type an employee may take in a year:

    * their policy (or the default policy) decides which types apply, the
      days per year and the carry-over of last year's unused days (at most
      `carry_over_days`, never more than last year's leftover);
    * with no policy at all, the leave type's own default allowance applies.

  `allowance: nil` means no limit.
  """

  require Ash.Query

  alias Zippiker.HR.{LeavePolicy, LeavePolicyRule, LeaveRequest}

  @type t :: %{
          available?: boolean(),
          policy: map() | nil,
          allowance: Decimal.t() | nil,
          carried_over: Decimal.t()
        }

  @doc "Entitlement for `employee` (needs `leave_policy_id`) and `leave_type` in `year`."
  def for(employee, leave_type, year, tenant) do
    opts = [tenant: tenant, authorize?: false]

    case policy(employee, opts) do
      nil ->
        %{
          available?: true,
          policy: nil,
          allowance: leave_type.allowance_days,
          carried_over: zero()
        }

      policy ->
        case rule(policy.id, leave_type.id, opts) do
          nil ->
            %{available?: false, policy: policy, allowance: zero(), carried_over: zero()}

          rule ->
            %{
              available?: true,
              policy: policy,
              allowance: rule.days_per_year,
              carried_over: carry_over(employee.id, leave_type.id, rule, year - 1, opts)
            }
        end
    end
  end

  @doc "Days of the type pending or approved for the employee in `year`."
  def used(employee_id, leave_type_id, year, opts, exclude_id \\ nil) do
    LeaveRequest
    |> Ash.Query.filter(
      employee_id == ^employee_id and leave_type_id == ^leave_type_id and
        status in [:pending, :approved] and start_date >= ^Date.new!(year, 1, 1) and
        start_date <= ^Date.new!(year, 12, 31)
    )
    |> then(fn query ->
      if exclude_id, do: Ash.Query.filter(query, id != ^exclude_id), else: query
    end)
    |> Ash.sum!(:days, opts)
    |> case do
      nil -> zero()
      sum -> sum
    end
  end

  defp policy(%{leave_policy_id: id}, opts) when is_binary(id),
    do: Ash.get!(LeavePolicy, id, opts)

  defp policy(_employee, opts) do
    LeavePolicy |> Ash.Query.filter(default? == true) |> Ash.read_one!(opts)
  end

  defp rule(policy_id, type_id, opts) do
    LeavePolicyRule
    |> Ash.Query.filter(leave_policy_id == ^policy_id and leave_type_id == ^type_id)
    |> Ash.read_one!(opts)
  end

  defp carry_over(_employee_id, _type_id, %{days_per_year: nil}, _year, _opts), do: zero()

  defp carry_over(employee_id, type_id, rule, last_year, opts) do
    if Decimal.gt?(rule.carry_over_days, 0) do
      leftover =
        rule.days_per_year
        |> Decimal.sub(used(employee_id, type_id, last_year, opts))
        |> Decimal.max(zero())

      Decimal.min(leftover, rule.carry_over_days)
    else
      zero()
    end
  end

  defp zero, do: Decimal.new(0)
end
