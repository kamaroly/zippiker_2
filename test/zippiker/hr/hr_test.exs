defmodule Zippiker.HRTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{HR, Parties}

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]

    annual = HR.create_leave_type!(%{name: "Annual", allowance_days: Decimal.new(10)}, opts)
    sick = HR.create_leave_type!(%{name: "Sick", requires_approval?: false}, opts)

    %{owner: owner, organization: organization, opts: opts, annual: annual, sick: sick}
  end

  defp hire(opts, attrs) do
    HR.hire_employee!(Map.merge(%{first_name: "Ada", last_name: "Lovelace"}, attrs), opts)
  end

  # A Monday, so ranges are easy to reason about.
  @monday ~D[2026-11-02]

  test "hiring creates the person in Parties and numbers the employee", %{opts: opts} do
    ada = hire(opts, %{email: "ada@acme.test", job_title: "Engineer"})
    grace = hire(opts, %{first_name: "Grace", last_name: "Hopper"})

    assert ada.employee_number == "EMP-0001"
    assert grace.employee_number == "EMP-0002"

    party = Parties.get_party!(ada.party_id, opts)
    assert party.name == "Ada Lovelace"
    assert :employee in party.roles
    assert party.job_title == "Engineer"

    ada = HR.update_employee!(ada, %{first_name: "Augusta Ada", job_title: "Lead"}, opts)
    assert Parties.get_party!(ada.party_id, opts).name == "Augusta Ada Lovelace"

    assert {:error, %Ash.Error.Invalid{}} = HR.hire_employee(%{last_name: "Nameless"}, opts)
  end

  test "reporting lines can't loop", %{opts: opts} do
    boss = hire(opts, %{first_name: "Boss"})
    lead = hire(opts, %{first_name: "Lead", manager_id: boss.id})
    dev = hire(opts, %{first_name: "Dev", manager_id: lead.id})

    assert {:error, %Ash.Error.Invalid{}} = HR.update_employee(boss, %{manager_id: dev.id}, opts)
    assert {:error, %Ash.Error.Invalid{}} = HR.update_employee(boss, %{manager_id: boss.id}, opts)

    [%{employee: %{id: top}, reports: [%{reports: [%{employee: %{id: bottom}}]}]}] =
      HR.org_chart!(opts)

    assert top == boss.id
    assert bottom == dev.id
  end

  test "leave counts working days, needs the manager's approval and uses the allowance",
       %{organization: organization, opts: opts, annual: annual} do
    manager_user = member_fixture(organization)
    staff_user = member_fixture(organization)
    manager = hire(opts, %{first_name: "Mia", user_id: manager_user.id})
    staff = hire(opts, %{first_name: "Sam", user_id: staff_user.id, manager_id: manager.id})

    staff_opts = [actor: staff_user, tenant: organization]
    manager_opts = [actor: manager_user, tenant: organization]

    # Mon–Sun = 5 working days; the employee is the actor's own record.
    request =
      HR.request_leave!(
        %{leave_type_id: annual.id, start_date: @monday, end_date: Date.add(@monday, 6)},
        staff_opts
      )

    assert request.employee_id == staff.id
    assert request.status == :pending
    assert Decimal.eq?(request.days, 5)

    # Overlaps, and over the allowance.
    assert {:error, _} =
             HR.request_leave(
               %{leave_type_id: annual.id, start_date: @monday, end_date: @monday},
               staff_opts
             )

    assert {:error, _} =
             HR.request_leave(
               %{
                 leave_type_id: annual.id,
                 start_date: Date.add(@monday, 14),
                 end_date: Date.add(@monday, 21)
               },
               staff_opts
             )

    # Members can't request for someone else, nor approve their own.
    assert {:error, %Ash.Error.Forbidden{}} =
             HR.request_leave(
               %{
                 employee_id: manager.id,
                 leave_type_id: annual.id,
                 start_date: @monday,
                 end_date: @monday
               },
               staff_opts
             )

    assert {:error, %Ash.Error.Forbidden{}} = HR.approve_leave(request, staff_opts)

    assert [%{id: id}] = HR.list_leave_requests!(%{to_decide?: true}, manager_opts)
    assert id == request.id

    approved = HR.approve_leave!(request, %{decision_note: "Enjoy"}, manager_opts)
    assert approved.status == :approved
    assert approved.decided_by_id == manager_user.id

    [balance] =
      HR.leave_balances!(staff.id, %{year: 2026}, opts)
      |> Enum.filter(&(&1.leave_type.id == annual.id))

    assert Decimal.eq?(balance.taken, 5)
    assert Decimal.eq?(balance.left, 5)

    HR.cancel_leave!(approved, staff_opts)

    [balance] =
      HR.leave_balances!(staff.id, %{year: 2026}, opts)
      |> Enum.filter(&(&1.leave_type.id == annual.id))

    assert Decimal.eq?(balance.left, 10)
  end

  test "admins decide for people without a login", %{opts: opts, annual: annual} do
    ada = hire(opts, %{})

    request =
      HR.request_leave!(
        %{employee_id: ada.id, leave_type_id: annual.id, start_date: @monday, end_date: @monday},
        opts
      )

    assert HR.approve_leave!(request, opts).status == :approved
  end

  test "types without approval are approved straight away", %{opts: opts, sick: sick} do
    ada = hire(opts, %{})

    request =
      HR.request_leave!(
        %{employee_id: ada.id, leave_type_id: sick.id, start_date: @monday, end_date: @monday},
        opts
      )

    assert request.status == :approved
  end

  test "weekends alone aren't leave; people who left can't request", %{opts: opts, annual: annual} do
    ada = hire(opts, %{})
    saturday = Date.add(@monday, 5)

    assert {:error, _} =
             HR.request_leave(
               %{
                 employee_id: ada.id,
                 leave_type_id: annual.id,
                 start_date: saturday,
                 end_date: Date.add(saturday, 1)
               },
               opts
             )

    ada = HR.terminate_employee!(ada, %{termination_reason: "Moved abroad"}, opts)
    assert ada.status == :terminated
    assert ada.termination_date == Date.utc_today()

    assert {:error, _} =
             HR.request_leave(
               %{
                 employee_id: ada.id,
                 leave_type_id: annual.id,
                 start_date: @monday,
                 end_date: @monday
               },
               opts
             )

    assert HR.rehire_employee!(ada, opts).status == :active
  end

  test "pay is hidden from other members", %{organization: organization, opts: opts} do
    colleague = member_fixture(organization)
    ada = hire(opts, %{salary: Decimal.new(5000)})

    seen = HR.get_employee!(ada.id, actor: colleague, tenant: organization)
    assert %Ash.ForbiddenField{} = seen.salary
    assert Decimal.eq?(HR.get_employee!(ada.id, opts).salary, 5000)
  end

  test "summary", %{opts: opts, sick: sick} do
    ada = hire(opts, %{})
    today = Date.utc_today()

    # On a weekend there are no working days to take off.
    weekday? = Date.day_of_week(today) in 1..5

    result =
      HR.request_leave(
        %{employee_id: ada.id, leave_type_id: sick.id, start_date: today, end_date: today},
        opts
      )

    assert match?({:ok, _}, result) == weekday?

    summary = HR.hr_summary!(opts)
    assert summary.headcount == 1
    assert summary.new_hires_30d == 1
    assert summary.off_today == if(weekday?, do: 1, else: 0)
  end
end
