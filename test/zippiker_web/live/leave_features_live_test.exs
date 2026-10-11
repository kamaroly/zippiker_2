defmodule ZippikerWeb.LeaveFeaturesLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.HR

  setup :register_and_log_in_user

  setup %{opts: opts, user: user} do
    sick = HR.create_leave_type!(%{name: "Sick"}, opts)
    me = HR.hire_employee!(%{first_name: "Owner", user_id: user.id}, opts)
    %{sick: sick, me: me}
  end

  test "new pages render", %{conn: conn} do
    for path <- ~w(/hr/holidays /hr/holidays/new /hr/leave-claims /hr/leave-claims/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "help, platform admin and the user menu sit in the top bar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/hr/holidays")
    assert has_element?(view, "#top-bar #top-help")
    assert has_element?(view, "#top-bar #user-menu #sign-out")
    refute has_element?(view, "#top-bar #top-platform")
  end

  test "adds a holiday", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/hr/holidays/new")

    view
    |> form("#holiday-form", holiday: %{name: "New Year", date: "2027-01-01", recurring?: "true"})
    |> render_submit()

    assert [%{name: "New Year", recurring?: true}] = HR.list_holidays!(opts)
  end

  test "a required supporting document is uploaded with the request and downloadable", %{
    conn: conn,
    opts: opts,
    sick: sick,
    me: me
  } do
    HR.create_leave_policy!(
      %{
        name: "Sick",
        leave_type_id: sick.id,
        default?: true,
        category: :unlimited,
        requires_attachment?: true
      },
      opts
    )

    {:ok, view, _html} = live(conn, ~p"/hr/leave/new")
    monday = Date.add(Date.utc_today(), 8 - Date.day_of_week(Date.utc_today()))
    params = %{employee_id: me.id, leave_type_id: sick.id, start_date: monday, end_date: monday}

    view |> form("#leave-form", leave: params) |> render_change()
    assert has_element?(view, "#leave-attachment", "required")

    # Without a file it's refused.
    view |> form("#leave-form", leave: params) |> render_submit()
    assert HR.list_leave_requests!(%{}, opts) == []

    file =
      file_input(view, "#leave-form", :attachment, [
        %{name: "doctor.pdf", content: "%PDF-1.4 note", type: "application/pdf"}
      ])

    render_upload(file, "doctor.pdf")
    view |> form("#leave-form", leave: params) |> render_submit()

    [request] = HR.list_leave_requests!(%{}, opts)
    assert request.attachment_name == "doctor.pdf"

    conn = get(conn, ~p"/hr/leave/#{request.id}/attachment")
    assert response(conn, 200) == "%PDF-1.4 note"
  end

  test "claims leave and the admin adjusts balances", %{conn: conn, opts: opts, me: me} do
    toil = HR.create_leave_type!(%{name: "TOIL"}, opts)

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

    {:ok, view, _html} = live(conn, ~p"/hr/leave-claims/new")

    view
    |> form("#claim-form",
      claim: %{
        employee_id: me.id,
        leave_type_id: toil.id,
        days: "1",
        worked_on: "2026-10-03",
        reason: "Weekend"
      }
    )
    |> render_submit()

    assert [%{status: :pending}] = HR.list_leave_claims!(%{}, opts)

    {:ok, view, _html} = live(conn, ~p"/hr/employees/#{me}/adjust-leave")

    view
    |> form("#adjust-leave-form", adjust: %{leave_type_id: toil.id, days: "3", note: "Opening"})
    |> render_submit()

    assert [%{days: days}] = HR.leave_balance_entries!(me.id, opts)
    assert Decimal.eq?(days, 3)
  end
end
