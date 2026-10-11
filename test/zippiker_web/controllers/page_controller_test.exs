defmodule ZippikerWeb.PageControllerTest do
  use ZippikerWeb.ConnCase, async: true

  import Zippiker.Fixtures

  test "visitors see the landing page with a sign-up call to action", %{conn: conn} do
    plan_fixture(%{name: "Growth"})
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "One system."
    assert html =~ ~s(id="lp-hero-cta")
    assert html =~ ~s(href="/register")
    assert html =~ "Growth"
  end

  test "signed-in people go to their dashboard", %{conn: conn} do
    {user, _organization} = workspace_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/")
    assert redirected_to(conn) == "/dashboard"
  end
end
