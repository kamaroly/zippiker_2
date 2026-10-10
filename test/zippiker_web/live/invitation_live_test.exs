defmodule ZippikerWeb.InvitationLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.Accounts

  setup :register_and_log_in_user

  test "invitation link: anonymous → register; signed in → accept and switch", %{
    opts: opts,
    organization: organization
  } do
    invitation = Accounts.invite!(%{email: "joiner@example.com"}, opts)

    anon = build_conn() |> get(~p"/invitations/#{invitation.token}")
    assert redirected_to(anon) == "/register"
    assert get_session(anon, :return_to) == "/invitations/#{invitation.token}/accept"

    joiner = Zippiker.Fixtures.user_fixture(%{email: "joiner@example.com"})

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(joiner)

    {:ok, view, _html} = live(conn, ~p"/invitations/#{invitation.token}/accept")
    view |> element("#accept-invitation") |> render_click()

    conn = follow_trigger_action(form(view, "#switch-form"), conn)
    assert redirected_to(conn) == "/"
    assert get_session(conn, :organization_id) == organization.id
  end

  test "switching to a workspace you don't belong to is refused", %{conn: conn} do
    {_other_user, other_org} = Zippiker.Fixtures.workspace_fixture()
    conn = post(conn, ~p"/workspaces/#{other_org.id}/switch")
    assert get_session(conn, :organization_id) == nil
  end
end
