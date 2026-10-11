defmodule ZippikerWeb.TimeLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.HR

  setup :register_and_log_in_user

  setup %{opts: opts, user: user} do
    %{employee: HR.hire_employee!(%{first_name: "Ada", user_id: user.id}, opts)}
  end

  test "log, edit and delete time", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/hr/time")
    assert has_element?(view, "#time-activities")

    view |> element("#log-time") |> render_click()

    view
    |> form("#time-form",
      time: %{hours: "2.5", description: "Site visit", billable?: "true", hourly_rate: "40"}
    )
    |> render_submit()

    assert has_element?(view, "#time-activities", "Site visit")
    assert has_element?(view, "#total-hours", "2.5")

    [activity] = HR.list_time_activities!(%{}, opts)
    assert activity.billable?

    {:ok, view, _html} = live(conn, ~p"/hr/time/#{activity}/edit")
    view |> form("#time-form", time: %{hours: "3"}) |> render_submit()
    assert has_element?(view, "#total-hours", "3")

    view |> element("#time-activities a", "Delete") |> render_click()
    assert HR.list_time_activities!(%{}, opts) == []
  end

  test "members only see and log their own time", %{organization: organization, opts: opts} do
    member = member_fixture(organization)
    member_employee = HR.hire_employee!(%{first_name: "Bo", user_id: member.id}, opts)
    HR.log_time!(%{date: Date.utc_today(), hours: "4", description: "Admin's work"}, opts)

    member_opts = [actor: member, tenant: organization]

    activity =
      HR.log_time!(%{date: Date.utc_today(), hours: "1", description: "Mine"}, member_opts)

    assert activity.employee_id == member_employee.id

    conn = log_in_user(build_conn(), member)
    {:ok, view, _html} = live(conn, ~p"/hr/time")
    assert has_element?(view, "#time-activities", "Mine")
    refute has_element?(view, "#time-activities", "Admin's work")
    refute has_element?(view, "#time-employee")
  end
end
