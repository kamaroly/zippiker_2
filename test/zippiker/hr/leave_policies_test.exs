defmodule Zippiker.HR.LeavePoliciesTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.HR

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    annual = HR.create_leave_type!(%{name: "Annual", allowance_days: Decimal.new(10)}, opts)
    sick = HR.create_leave_type!(%{name: "Sick"}, opts)
    toil = HR.create_leave_type!(%{name: "Time off in lieu"}, opts)
    %{opts: opts, organization: organization, annual: annual, sick: sick, toil: toil}
  end

  # A Monday in the future, so ranges are easy to reason about.
  @monday ~D[2026-11-02]

  defp hire(opts, attrs \\ %{}),
    do:
      HR.hire_employee!(
        Map.merge(%{first_name: "Ada", last_name: "Lovelace", hire_date: ~D[2025-01-01]}, attrs),
        opts
      )

  defp balance(employee, type, opts, year \\ 2026),
    do:
      Enum.find(
        HR.leave_balances!(employee.id, %{year: year}, opts),
        &(&1.leave_type.id == type.id)
      )

  defp request(opts, attrs),
    do: HR.request_leave(Map.merge(%{start_date: @monday, end_date: @monday}, attrs), opts)

  test "a policy per leave type: default for everyone, own policy wins, carry-over",
       %{opts: opts, annual: annual} do
    HR.create_leave_policy!(
      %{
        name: "Annual",
        leave_type_id: annual.id,
        default?: true,
        days_per_year: "15",
        carry_over_days: "5",
        effective_date: ~D[2026-01-01]
      },
      opts
    )

    senior =
      HR.create_leave_policy!(
        %{name: "Annual senior", leave_type_id: annual.id, days_per_year: "25"},
        opts
      )

    ada = hire(opts)
    bob = hire(opts, %{first_name: "Bob"})
    HR.assign_leave_policy!(senior, %{employee_ids: [bob.id]}, opts)

    assert Decimal.eq?(balance(ada, annual, opts).allowance, 15)
    assert Decimal.eq?(balance(bob, annual, opts).allowance, 25)

    # Ada uses 10 of 15 in 2026: 5 roll into 2027.
    {:ok, req} =
      request(opts, %{
        employee_id: ada.id,
        leave_type_id: annual.id,
        end_date: Date.add(@monday, 11)
      })

    HR.approve_leave!(req, opts)

    next = balance(ada, annual, opts, 2027)
    assert Decimal.eq?(next.carried_over, 5)
    assert Decimal.eq?(next.left, 20)

    # Only one default per leave type.
    other =
      HR.create_leave_policy!(
        %{name: "Annual v2", leave_type_id: annual.id, default?: true, days_per_year: "1"},
        opts
      )

    assert other.default?
    refute Enum.find(HR.list_leave_policies!(opts), &(&1.name == "Annual")).default?
  end

  test "assigning by department replaces the previous policy for that type",
       %{opts: opts, annual: annual} do
    sales = HR.create_department!(%{name: "Sales"}, opts)
    ada = hire(opts, %{department_id: sales.id})
    other = hire(opts, %{first_name: "Other"})

    a = HR.create_leave_policy!(%{name: "A", leave_type_id: annual.id, days_per_year: "5"}, opts)
    b = HR.create_leave_policy!(%{name: "B", leave_type_id: annual.id, days_per_year: "7"}, opts)

    HR.assign_leave_policy!(a, %{employee_ids: [ada.id, other.id]}, opts)
    HR.assign_leave_policy!(b, %{department_id: sales.id}, opts)

    assert Decimal.eq?(balance(ada, annual, opts).allowance, 7)
    assert Decimal.eq?(balance(other, annual, opts).allowance, 5)
    assert [%{employees_count: 1}, %{employees_count: 1}] = HR.list_leave_policies!(opts)
  end

  test "accruals are credited by period, idempotently, up to the cap",
       %{opts: opts, annual: annual} do
    HR.create_leave_policy!(
      %{
        name: "Accruing",
        leave_type_id: annual.id,
        default?: true,
        category: :accrual,
        accrual_days: "1.5",
        accrual_frequency: :monthly,
        accrual_cap: "5",
        effective_date: ~D[2026-07-15]
      },
      opts
    )

    ada = hire(opts)

    # Aug 1, Sep 1, Oct 1 → 4.5 days.
    assert %{credited: 3} = HR.run_leave_accruals!(%{as_of: ~D[2026-10-10]}, opts)
    assert %{credited: 0} = HR.run_leave_accruals!(%{as_of: ~D[2026-10-10]}, opts)
    assert Decimal.eq?(balance(ada, annual, opts).left, "4.5")

    # Nov 1 is capped at 5 (only 0.5 more); Dec 1 adds nothing.
    HR.run_leave_accruals!(%{as_of: ~D[2026-12-05]}, opts)
    assert Decimal.eq?(balance(ada, annual, opts).left, 5)

    # The balance limits requests (1 working day is fine, 6 aren't).
    assert {:error, %Ash.Error.Invalid{}} =
             request(opts, %{
               employee_id: ada.id,
               leave_type_id: annual.id,
               end_date: Date.add(@monday, 7)
             })

    assert {:ok, _} = request(opts, %{employee_id: ada.id, leave_type_id: annual.id})
  end

  test "the Oban jobs run accruals and overdue reviews for every workspace",
       %{opts: opts, annual: annual, sick: sick} do
    HR.create_leave_policy!(
      %{
        name: "Accruing",
        leave_type_id: annual.id,
        default?: true,
        category: :accrual,
        accrual_days: "2",
        accrual_frequency: :yearly,
        effective_date: ~D[2026-01-01]
      },
      opts
    )

    HR.create_leave_policy!(
      %{
        name: "Sick",
        leave_type_id: sick.id,
        default?: true,
        category: :unlimited,
        review_threshold_days: 2,
        overdue_action: :approve
      },
      opts
    )

    ada = hire(opts)

    assert :ok =
             Oban.Testing.perform_job(Zippiker.HR.Workers.RunAccruals, %{"as_of" => "2026-10-10"},
               repo: Zippiker.Repo
             )

    assert Decimal.eq?(balance(ada, annual, opts).left, 2)

    {:ok, pending} = request(opts, %{employee_id: ada.id, leave_type_id: sick.id})
    assert pending.status == :pending

    # Not overdue yet.
    assert %{decided: 0} = HR.review_overdue_leave!(%{}, opts)

    # Three days later it's approved automatically.
    assert %{decided: 1} =
             HR.review_overdue_leave!(%{now: DateTime.add(DateTime.utc_now(), 3, :day)}, opts)

    decided = HR.get_leave_request!(pending.id, opts)
    assert decided.status == :approved
    assert decided.auto_decided?

    assert :ok =
             Oban.Testing.perform_job(Zippiker.HR.Workers.ReviewOverdueLeave, %{},
               repo: Zippiker.Repo
             )
  end

  test "request rules: attachment, backdating, weekends and holidays",
       %{opts: opts, organization: organization, sick: sick, annual: annual} do
    HR.create_leave_policy!(
      %{
        name: "Sick",
        leave_type_id: sick.id,
        default?: true,
        category: :unlimited,
        requires_attachment?: true,
        allow_backdated?: false,
        count_weekends_and_holidays?: true
      },
      opts
    )

    user = member_fixture(organization)
    ada = hire(opts, %{user_id: user.id})
    staff_opts = [actor: user, tenant: organization]

    assert {:error, %Ash.Error.Invalid{}} = request(staff_opts, %{leave_type_id: sick.id})

    # Mon–Sun counts 7 calendar days for this policy.
    {:ok, sick_leave} =
      request(staff_opts, %{
        leave_type_id: sick.id,
        end_date: Date.add(@monday, 6),
        attachment_name: "note.pdf",
        attachment_path: "x/leave/note.pdf"
      })

    assert Decimal.eq?(sick_leave.days, 7)

    # Past dates are refused for staff, allowed for admins.
    past = %{
      leave_type_id: sick.id,
      start_date: ~D[2026-01-05],
      end_date: ~D[2026-01-05],
      attachment_name: "n.pdf",
      attachment_path: "x/leave/n.pdf"
    }

    assert {:error, %Ash.Error.Invalid{}} = request(staff_opts, past)
    assert {:ok, _} = request(opts, Map.put(past, :employee_id, ada.id))

    # Annual (no policy) skips the weekend and a holiday: Mon 9 – Sun 15 minus Tue 10 = 4.
    HR.create_holiday!(%{name: "Founders' day", date: ~D[2025-11-10], recurring?: true}, opts)

    {:ok, annual_leave} =
      request(staff_opts, %{
        leave_type_id: annual.id,
        start_date: ~D[2026-11-09],
        end_date: ~D[2026-11-15]
      })

    assert Decimal.eq?(annual_leave.days, 4)
  end

  test "claims add days once approved by the manager; manual policies use adjustments",
       %{opts: opts, organization: organization, toil: toil} do
    HR.create_leave_policy!(
      %{
        name: "TOIL",
        leave_type_id: toil.id,
        default?: true,
        category: :manual,
        claimable?: true
      },
      opts
    )

    manager_user = member_fixture(organization)
    staff_user = member_fixture(organization)
    manager = hire(opts, %{first_name: "Mia", user_id: manager_user.id})
    staff = hire(opts, %{first_name: "Sam", user_id: staff_user.id, manager_id: manager.id})
    staff_opts = [actor: staff_user, tenant: organization]
    manager_opts = [actor: manager_user, tenant: organization]

    assert Decimal.eq?(balance(staff, toil, opts).left, 0)

    claim =
      HR.claim_leave!(
        %{
          leave_type_id: toil.id,
          days: "1",
          worked_on: ~D[2026-10-03],
          reason: "Saturday stock count"
        },
        staff_opts
      )

    assert {:error, %Ash.Error.Forbidden{}} = HR.approve_leave_claim(claim, staff_opts)
    assert [%{id: id}] = HR.list_leave_claims!(%{to_decide?: true}, manager_opts)
    assert id == claim.id

    HR.approve_leave_claim!(claim, manager_opts)
    assert Decimal.eq?(balance(staff, toil, opts).left, 1)

    # Admin adjustment.
    HR.adjust_leave_balance!(
      %{employee_id: staff.id, leave_type_id: toil.id, days: "2", note: "Opening"},
      opts
    )

    assert Decimal.eq?(balance(staff, toil, opts).left, 3)

    assert {:error, %Ash.Error.Forbidden{}} =
             HR.adjust_leave_balance(
               %{employee_id: staff.id, leave_type_id: toil.id, days: "9"},
               staff_opts
             )

    # A type whose policy isn't claimable can't be claimed.
    assert {:error, %Ash.Error.Invalid{}} =
             HR.claim_leave(
               %{
                 leave_type_id: opts |> HR.list_leave_types!() |> hd() |> Map.get(:id),
                 days: "1",
                 worked_on: ~D[2026-10-03],
                 reason: "x"
               },
               staff_opts
             )
  end
end
