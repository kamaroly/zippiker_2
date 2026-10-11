defmodule ZippikerWeb.PlatformLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Platform}

  describe "access" do
    setup :register_and_log_in_user

    test "regular users are sent back to their workspace", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/platform")
    end

    test "regular users can't impersonate or open workspaces", %{
      conn: conn,
      organization: organization
    } do
      other = user_fixture()
      conn = post(conn, ~p"/platform/users/#{other.id}/impersonate")
      assert redirected_to(conn) == "/"

      conn = post(recycle(conn), ~p"/platform/teams/#{organization.id}/access")
      assert redirected_to(conn) == "/"
      assert get_session(conn, :impersonator_id) == nil
    end
  end

  describe "super admin" do
    setup %{conn: conn} do
      admin = super_admin_fixture()
      {owner, team} = workspace_fixture(%{name: "Initech"})
      %{conn: log_in_user(conn, admin), admin: admin, owner: owner, team: team}
    end

    test "every platform page renders", %{conn: conn, team: team} do
      for path <- [
            ~p"/platform",
            ~p"/platform/teams",
            ~p"/platform/teams?status=trialing",
            ~p"/platform/teams/#{team}",
            ~p"/platform/users",
            ~p"/platform/plans",
            ~p"/platform/billing"
          ] do
        assert {:ok, _view, _html} = live(conn, path)
      end
    end

    test "lists and searches workspaces", %{conn: conn, team: team} do
      {:ok, view, _html} = live(conn, ~p"/platform/teams")
      assert has_element?(view, "#teams-#{team.id}")

      view |> element("#team-search") |> render_change(%{q: "nope"})
      refute has_element?(view, "#teams-#{team.id}")
    end

    test "switches modules and seat limit for a workspace", %{conn: conn, team: team} do
      {:ok, view, _html} = live(conn, ~p"/platform/teams/#{team}")

      view
      |> element("#limits-form")
      |> render_submit(%{"modules" => ["crm"], "seat_limit" => "5"})

      team = Ash.get!(Accounts.Organization, team.id, authorize?: false)
      assert team.enabled_modules == [:crm]
      assert team.seat_limit == 5
      assert has_element?(view, "#team-events", "Modules: CRM")
    end

    test "changes the plan and bills the period", %{conn: conn, team: team} do
      plan = plan_fixture(%{name: "Scale", price_per_seat: Decimal.new(30)})
      {:ok, view, _html} = live(conn, ~p"/platform/teams/#{team}/subscription")

      view
      |> form("#subscription-form", subscription: %{plan_id: plan.id, status: "active"})
      |> render_submit()

      assert_patch(view, ~p"/platform/teams/#{team}")
      assert has_element?(view, "#subscription-card", "Scale")

      view |> element("#generate-invoice") |> render_click()
      assert has_element?(view, "#team-invoices", "ZPK-")

      [invoice] = Platform.list_billing_invoices!(%{organization_id: team.id}, authorize?: false)
      view |> element("#invoices-#{invoice.id} button", "Mark paid") |> render_click()
      assert Platform.get_billing_invoice!(invoice.id, authorize?: false).status == :paid
    end

    test "creates a plan", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/plans/new")

      view
      |> form("#plan-form",
        plan: %{
          name: "Starter",
          code: "starter",
          price_per_seat: "5",
          currency: "USD",
          trial_days: "7",
          modules: ["", "crm", "sales"]
        }
      )
      |> render_submit()

      assert_patch(view, ~p"/platform/plans")

      assert %{modules: [:crm, :sales], trial_days: 7} =
               Enum.find(Platform.list_plans!(authorize?: false), &(&1.code == "starter"))
    end

    test "impersonates a user and comes back", %{conn: conn, admin: admin, owner: owner} do
      conn = post(conn, ~p"/platform/users/#{owner.id}/impersonate")
      assert redirected_to(conn) == "/"
      assert get_session(conn, :impersonator_id) == admin.id

      {:ok, view, _html} = live(recycle(conn), ~p"/dashboard")
      assert has_element?(view, "#platform-banner", owner.email |> to_string())
      assert has_element?(view, "#stop-impersonating")

      conn = delete(recycle(conn), ~p"/platform/impersonation")
      assert redirected_to(conn) == "/platform/users"
      assert get_session(conn, :impersonator_id) == nil

      assert {:ok, _view, _html} = live(recycle(conn), ~p"/platform")

      actions =
        Platform.list_audit_events!(%{}, actor: admin)
        |> Enum.map(& &1.action)

      assert :impersonation_started in actions
      assert :impersonation_stopped in actions
    end

    test "won't impersonate another super admin", %{conn: conn} do
      other_admin = super_admin_fixture()
      conn = post(conn, ~p"/platform/users/#{other_admin.id}/impersonate")
      assert redirected_to(conn) == "/platform/users"
    end

    test "opens a workspace as admin with a banner", %{conn: conn, team: team} do
      conn = post(conn, ~p"/platform/teams/#{team.id}/access")
      assert redirected_to(conn) == "/"

      {:ok, view, _html} = live(recycle(conn), ~p"/contacts")
      assert has_element?(view, "#platform-banner", "Initech")
      assert has_element?(view, "#leave-workspace")

      conn = delete(recycle(conn), ~p"/platform/access")
      assert redirected_to(conn) == "/platform/teams"
    end

    test "grants super admin from the users page", %{conn: conn, owner: owner} do
      {:ok, view, _html} = live(conn, ~p"/platform/users")
      view |> element("#toggle-admin-#{owner.id}") |> render_click()
      assert Ash.get!(Accounts.User, owner.id, authorize?: false).super_admin?
    end
  end
end
