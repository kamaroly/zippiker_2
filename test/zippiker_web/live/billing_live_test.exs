defmodule ZippikerWeb.BillingLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.Platform

  setup :register_and_log_in_user

  test "admins see their plan, seats and can set the billing contact", %{
    conn: conn,
    organization: organization
  } do
    {:ok, view, _html} = live(conn, ~p"/settings/billing")
    assert has_element?(view, "#current-plan")

    view
    |> form("#billing-form", billing: %{billing_email: "ap@acme.test"})
    |> render_submit()

    subscription = Platform.ensure_subscription!(organization.id, authorize?: false)
    assert to_string(subscription.billing_email) == "ap@acme.test"
  end

  test "requesting another plan notifies the platform team", %{
    conn: conn,
    organization: organization
  } do
    plan = plan_fixture(%{name: "Scale"})
    {:ok, view, _html} = live(conn, ~p"/settings/billing")

    view |> element("#request-plan-#{plan.id}") |> render_click()

    assert [%{action: :plan_requested}] =
             Platform.list_audit_events!(%{organization_id: organization.id}, authorize?: false)
  end

  test "members are told billing is for admins", %{conn: conn, organization: organization} do
    member = member_fixture(organization)
    {:ok, view, _html} = live(log_in_user(conn, member), ~p"/settings/billing")
    refute has_element?(view, "#current-plan")
  end
end
