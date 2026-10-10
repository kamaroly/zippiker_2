defmodule ZippikerWeb.WorkspaceImpersonationTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.Platform

  setup :register_and_log_in_user

  defp impersonate(conn, organization, user),
    do: post(conn, ~p"/workspaces/#{organization.id}/impersonate/#{user.id}")

  test "the owner impersonates a member from Settings and comes back", %{
    conn: conn,
    organization: organization,
    user: owner
  } do
    member = member_fixture(organization)

    {:ok, view, _html} = live(conn, ~p"/settings/workspace")
    assert has_element?(view, "#impersonate-#{member.id}")
    refute has_element?(view, "#impersonate-#{owner.id}")

    conn = impersonate(conn, organization, member)
    assert redirected_to(conn) == "/"
    assert get_session(conn, :impersonator_id) == owner.id

    {:ok, view, _html} = live(recycle(conn), ~p"/")
    assert has_element?(view, "#platform-banner", to_string(member.email))

    # No impersonating from inside an impersonation.
    {:ok, view, _html} = live(recycle(conn), ~p"/settings/workspace")
    refute has_element?(view, "[id^='impersonate-']")

    conn = delete(recycle(conn), ~p"/platform/impersonation")
    assert redirected_to(conn) == "/settings/workspace"
    assert get_session(conn, :impersonator_id) == nil
    assert {:ok, _view, _html} = live(recycle(conn), ~p"/settings/workspace")

    actions =
      %{}
      |> Platform.list_audit_events!(authorize?: false)
      |> Enum.filter(&(&1.organization_id == organization.id))
      |> Enum.map(& &1.action)

    assert :impersonation_started in actions
    assert :impersonation_stopped in actions
  end

  test "admins can impersonate members but not other admins or the owner", %{
    organization: organization,
    user: owner
  } do
    admin = member_fixture(organization, :admin)
    other_admin = member_fixture(organization, :admin)
    member = member_fixture(organization)
    conn = log_in_user(build_conn(), admin)

    for target <- [owner, other_admin, admin] do
      conn = impersonate(conn, organization, target)
      assert redirected_to(conn) == "/settings/workspace"
      assert get_session(conn, :impersonator_id) == nil
    end

    conn = impersonate(conn, organization, member)
    assert get_session(conn, :impersonator_id) == admin.id
  end

  test "members and outsiders can't impersonate", %{organization: organization, user: owner} do
    member = member_fixture(organization)
    conn = impersonate(log_in_user(build_conn(), member), organization, owner)
    assert get_session(conn, :impersonator_id) == nil

    {outsider, _other_workspace} = workspace_fixture()
    conn = impersonate(log_in_user(build_conn(), outsider), organization, member)
    assert get_session(conn, :impersonator_id) == nil

    # Super admins are never impersonated by workspace admins.
    admin = super_admin_fixture()

    Zippiker.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: admin.id,
      organization_id: organization.id,
      role: :member
    })
    |> Ash.create!(authorize?: false)

    conn = impersonate(log_in_user(build_conn(), owner), organization, admin)
    assert get_session(conn, :impersonator_id) == nil
  end
end
