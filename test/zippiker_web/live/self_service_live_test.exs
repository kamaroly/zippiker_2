defmodule ZippikerWeb.SelfServiceLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.HR

  setup :register_and_log_in_user

  test "employees see their workspace, tasks and update their own details only", %{
    organization: organization,
    opts: opts
  } do
    staff = member_fixture(organization)
    other = member_fixture(organization)
    employee = HR.hire_employee!(%{first_name: "Sam", user_id: staff.id}, opts)
    HR.hire_employee!(%{first_name: "Olu", user_id: other.id}, opts)

    conn = log_in_user(build_conn(), staff)

    {:ok, view, _html} = live(conn, ~p"/me")
    assert has_element?(view, "#nav-me")
    assert has_element?(view, "#my-balances")
    assert has_element?(view, "#quick-actions", "Request leave")
    # The onboarding checklist gives Sam tasks of their own.
    assert has_element?(view, "#my-task-preview a")

    {:ok, tasks, _html} = live(conn, ~p"/me/tasks")
    assert has_element?(tasks, "#my-tasks li")

    {:ok, profile, _html} = live(conn, ~p"/me/profile")

    profile
    |> form("#my-details-form",
      me: %{
        phone: "+254 700 000 000",
        emergency_contact_name: "Ama",
        emergency_contact_phone: "0711"
      }
    )
    |> render_submit()

    updated = HR.get_employee!(employee.id, opts ++ [load: [:phone]])
    assert updated.phone == "+254 700 000 000"
    assert updated.emergency_contact_name == "Ama"

    # Nobody updates someone else's details through self-service.
    assert {:error, %Ash.Error.Forbidden{}} =
             HR.update_my_details(updated, %{emergency_contact_name: "X"},
               actor: other,
               tenant: organization
             )
  end

  test "people without an employee record get a friendly note", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me")
    assert render(view) =~ "No employee record yet"
  end
end
