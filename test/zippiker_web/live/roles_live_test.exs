defmodule ZippikerWeb.RolesLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.Accounts

  setup :register_and_log_in_user

  setup %{opts: opts} do
    %{roles: Map.new(Accounts.list_roles!(opts), &{&1.key, &1})}
  end

  defp member_with(organization, roles, keys, opts) do
    user = member_fixture(organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships
    Accounts.set_member_roles!(membership, Enum.map(keys, &roles[&1].id), opts)
    {user, membership}
  end

  test "lists the built-in roles and creates a custom one", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/settings/roles")
    assert has_element?(view, "#roles article", "Sales representative")
    assert has_element?(view, "#roles article", "Team member")

    view |> element("#new-role") |> render_click()
    assert has_element?(view, "#role-form")

    view |> element("#toggle-sales") |> render_click()
    assert has_element?(view, "#permission-invoices-create[checked]")

    view
    |> form("#role-form", role: %{name: "Cashier", description: "Takes payments"})
    |> render_submit()

    cashier = Enum.find(Accounts.list_roles!(opts), &(&1.name == "Cashier"))
    assert "payments.record" in cashier.permissions
    assert "invoices.create" in cashier.permissions
    assert has_element?(view, "#role-#{cashier.id}")
  end

  test "edits a role's permissions", %{conn: conn, opts: opts, roles: roles} do
    {:ok, view, _html} = live(conn, ~p"/settings/roles/#{roles["employee"].id}/edit")

    view
    |> form("#role-form", role: %{permissions: ["view.contacts", "view.reports"]})
    |> render_submit()

    assert Accounts.get_role!(roles["employee"].id, opts).permissions |> Enum.sort() ==
             ["view.contacts", "view.reports"]
  end

  test "gives a member roles from the workspace page",
       %{conn: conn, organization: organization, roles: roles} do
    user = member_fixture(organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships

    {:ok, view, _html} = live(conn, ~p"/settings/users")
    assert has_element?(view, "#member-roles-#{membership.id}", "Team member")

    view |> element("#edit-roles-#{membership.id}") |> render_click()

    view
    |> form("#member-roles-form", %{"role_ids" => [roles["sales_rep"].id]})
    |> render_submit()

    assert has_element?(view, "#member-roles-#{membership.id}", "Sales representative")
    refute has_element?(view, "#member-roles-#{membership.id}", "Team member")
  end

  test "members only see the modules their roles allow",
       %{organization: organization, roles: roles, opts: opts} do
    {user, _membership} = member_with(organization, roles, ["employee"], opts)
    conn = log_in_user(build_conn(), user)

    {:ok, view, _html} = live(conn, ~p"/dashboard")
    refute has_element?(view, "#sidebar a[href='/invoices']")
    assert has_element?(view, "#sidebar a[href='/me']")
    refute has_element?(view, "#command-palette-items a[href='/invoices/new']")

    assert {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} = live(conn, ~p"/invoices")
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/reports")
    assert {:ok, _view, _html} = live(conn, ~p"/hr/leave")
  end

  test "a sales rep sees Sales and its reports, not Accounting",
       %{organization: organization, roles: roles, opts: opts} do
    {user, _membership} = member_with(organization, roles, ["sales_rep"], opts)
    conn = log_in_user(build_conn(), user)

    {:ok, view, _html} = live(conn, ~p"/reports")
    assert has_element?(view, "#report-link-receivables-ar-ageing-summary")
    refute has_element?(view, "#report-group-accountant")
    assert {:error, {:redirect, _}} = live(conn, ~p"/accounting")
    assert {:error, {:live_redirect, %{to: "/reports"}}} = live(conn, ~p"/reports/general-ledger")
  end

  test "members without the permission can't edit roles",
       %{organization: organization, roles: roles, opts: opts} do
    {user, _membership} = member_with(organization, roles, ["team_member"], opts)
    conn = log_in_user(build_conn(), user)

    {:ok, view, _html} = live(conn, ~p"/settings/roles")
    refute has_element?(view, "#new-role")

    assert {:error, {:live_redirect, %{to: "/settings/roles"}}} =
             live(conn, ~p"/settings/roles/new")
  end
end
