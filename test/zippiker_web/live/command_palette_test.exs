defmodule ZippikerWeb.CommandPaletteTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  setup :register_and_log_in_user

  test "the top bar lists pages and actions the user can use", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#command-palette-open")

    assert has_element?(
             view,
             "#command-palette-items a[href='/hr/employees/new']",
             "New employee"
           )

    assert has_element?(view, "#command-palette-items a[href='/invoices']")
    assert has_element?(view, "[data-search*='hire']")
  end

  test "admin-only actions and disabled modules are left out", %{organization: organization} do
    member = member_fixture(organization)
    conn = log_in_user(build_conn(), member)

    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#command-palette-items a[href='/hr/employees/new']")
    assert has_element?(view, "#command-palette-items a[href='/hr/leave/new']", "Request leave")

    organization
    |> Ash.Changeset.for_update(:set_plan_limits, %{enabled_modules: [:crm, :sales]})
    |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#command-palette-items a[href='/hr/leave/new']")
    assert has_element?(view, "#command-palette-items a[href='/quotes/new']")
  end
end
