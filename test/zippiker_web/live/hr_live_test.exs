defmodule ZippikerWeb.HRLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Accounts, HR}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    annual = HR.create_leave_type!(%{name: "Annual", allowance_days: Decimal.new(20)}, opts)
    %{annual: annual}
  end

  # Next Monday, so the requested week always has working days.
  defp next_monday do
    today = Date.utc_today()
    Date.add(today, 8 - Date.day_of_week(today))
  end

  test "every HR page renders", %{conn: conn} do
    for path <-
          ~w(/hr/employees /hr/employees/new /hr/leave /hr/leave/new /hr/org-chart /hr/departments /hr/departments/new /hr/leave-types /hr/leave-types/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "hires an employee from the form", %{conn: conn, opts: opts, user: user} do
    {:ok, view, _html} = live(conn, ~p"/hr/employees/new")

    view
    |> form("#employee-form",
      employee: %{
        first_name: "Grace",
        last_name: "Hopper",
        email: "grace@acme.test",
        job_title: "CTO",
        user_id: user.id,
        salary: "9000"
      }
    )
    |> render_submit()

    {path, _flash} = assert_redirect(view)
    [grace] = HR.list_employees!(%{}, opts)
    assert path == "/hr/employees/#{grace.id}"
    assert grace.name == "Grace Hopper"

    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, "#employee-private", "9,000")

    {:ok, view, _html} = live(conn, ~p"/hr/employees")
    assert has_element?(view, "#employees-#{grace.id}", "CTO")
  end

  test "an employee requests leave and their manager approves it", %{
    opts: opts,
    organization: organization,
    annual: annual
  } do
    manager_user = member_fixture(organization)
    staff_user = member_fixture(organization)
    manager = HR.hire_employee!(%{first_name: "Mia", user_id: manager_user.id}, opts)

    HR.hire_employee!(
      %{first_name: "Sam", user_id: staff_user.id, manager_id: manager.id},
      opts
    )

    monday = next_monday()
    staff_conn = log_in_user(build_conn(), staff_user)
    {:ok, view, _html} = live(staff_conn, ~p"/hr/leave/new")

    view
    |> form("#leave-form",
      leave: %{
        leave_type_id: annual.id,
        start_date: Date.to_iso8601(monday),
        end_date: Date.to_iso8601(Date.add(monday, 4))
      }
    )
    |> render_change()

    assert has_element?(view, "#leave-preview", "5")

    view |> form("#leave-form") |> render_submit()
    assert_patch(view, ~p"/hr/leave?view=mine")

    [request] = HR.list_leave_requests!(%{}, opts)
    assert request.status == :pending
    refute has_element?(view, "#approve-#{request.id}")

    manager_conn = log_in_user(build_conn(), manager_user)
    {:ok, view, _html} = live(manager_conn, ~p"/hr/leave?view=approve")
    view |> element("#approve-#{request.id}") |> render_click()

    assert HR.get_leave_request!(request.id, opts).status == :approved
  end

  test "creates a department and a leave type", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/hr/departments/new")
    view |> form("#department-form", department: %{name: "Operations"}) |> render_submit()
    assert_patch(view, ~p"/hr/departments")
    assert [%{name: "Operations"}] = HR.list_departments!(opts)

    {:ok, view, _html} = live(conn, ~p"/hr/leave-types/new")

    view
    |> form("#leave-type-form", leave_type: %{name: "Sick", requires_approval?: "false"})
    |> render_submit()

    assert Enum.any?(HR.list_leave_types!(opts), &(&1.name == "Sick"))
  end

  test "marks someone as left", %{conn: conn, opts: opts} do
    ada = HR.hire_employee!(%{first_name: "Ada"}, opts)
    {:ok, view, _html} = live(conn, ~p"/hr/employees/#{ada}/terminate")

    view
    |> form("#termination-form", termination: %{termination_reason: "Relocated"})
    |> render_submit()

    assert HR.get_employee!(ada.id, opts).status == :terminated
    assert has_element?(view, "#rehire-employee")
  end

  test "org chart draws reporting lines", %{conn: conn, opts: opts} do
    boss = HR.hire_employee!(%{first_name: "Boss"}, opts)
    report = HR.hire_employee!(%{first_name: "Report", manager_id: boss.id}, opts)

    {:ok, view, _html} = live(conn, ~p"/hr/org-chart")
    assert has_element?(view, "#org-#{boss.id}")
    assert has_element?(view, "#org-#{report.id}")
  end

  test "HR pages are refused when the module is off", %{conn: conn, organization: organization} do
    Accounts.set_plan_limits!(organization, %{enabled_modules: [:crm]}, authorize?: false)
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/hr/employees")
  end
end
