defmodule Zippiker.PlatformTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Crm, Platform}

  describe "subscriptions" do
    test "a new workspace starts a trial on the default plan with its limits" do
      plan_fixture(%{default?: true, seat_limit: 3, modules: [:crm, :sales], trial_days: 14})
      {_user, organization} = workspace_fixture()

      subscription = Platform.ensure_subscription!(organization.id, authorize?: false)
      assert subscription.status == :trialing
      assert subscription.plan.seat_limit == 3
      assert subscription.trial_ends_on == Date.add(Date.utc_today(), 14)

      organization = Ash.get!(Accounts.Organization, organization.id, authorize?: false)
      assert organization.seat_limit == 3
      assert organization.enabled_modules == [:crm, :sales]
    end

    test "changing plan copies modules and seat limit to the workspace" do
      {_user, organization} = workspace_fixture()
      admin = super_admin_fixture()
      scale = plan_fixture(%{name: "Scale", seat_limit: nil, modules: [:crm]})

      organization.id
      |> Platform.ensure_subscription!(actor: admin)
      |> Platform.change_plan!(%{plan_id: scale.id, status: :active}, actor: admin)

      organization = Accounts.get_organization!(organization.id, actor: admin)
      assert organization.seat_limit == nil
      assert organization.enabled_modules == [:crm]
    end

    test "workspace owners can't change their own plan" do
      {user, organization} = workspace_fixture()
      scale = plan_fixture()
      subscription = Platform.ensure_subscription!(organization.id, actor: user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Platform.change_plan(subscription, %{plan_id: scale.id}, actor: user)

      assert {:ok, _} =
               Platform.update_billing_details(subscription, %{billing_email: "ap@acme.test"},
                 actor: user
               )
    end

    test "users can't read other workspaces' subscriptions" do
      {_user, organization} = workspace_fixture()
      {stranger, _other} = workspace_fixture()

      assert {:error, %Ash.Error.Forbidden{}} =
               Platform.ensure_subscription(organization.id, actor: stranger)
    end
  end

  describe "billing invoices" do
    test "bill seats × price for the current period, then advance the period" do
      admin = super_admin_fixture()
      {_user, organization} = workspace_fixture()
      member_fixture(organization)
      plan = plan_fixture(%{price_per_seat: Decimal.new("12.50")})

      subscription =
        organization.id
        |> Platform.ensure_subscription!(actor: admin)
        |> Platform.change_plan!(%{plan_id: plan.id}, actor: admin)

      invoice = Platform.generate_billing_invoice!(organization.id, actor: admin)
      assert invoice.number =~ ~r/^ZPK-\d{6}$/
      assert invoice.seats == 2
      assert Decimal.eq?(invoice.amount, Decimal.new("25.00"))
      assert invoice.period_start == subscription.current_period_start

      advanced = Platform.ensure_subscription!(organization.id, actor: admin)
      assert advanced.status == :active
      assert advanced.current_period_start == Date.add(subscription.current_period_end, 1)

      paid = Platform.mark_billing_invoice_paid!(invoice, %{}, actor: admin)
      assert paid.status == :paid
      assert paid.paid_on == Date.utc_today()
    end

    test "free plans have nothing to bill" do
      admin = super_admin_fixture()
      {_user, organization} = workspace_fixture()
      free = plan_fixture(%{price_per_seat: Decimal.new(0)})

      organization.id
      |> Platform.ensure_subscription!(actor: admin)
      |> Platform.change_plan!(%{plan_id: free.id}, actor: admin)

      assert {:error, %Ash.Error.Invalid{}} =
               Platform.generate_billing_invoice(organization.id, actor: admin)
    end
  end

  describe "seat limit" do
    test "invitations stop when members + pending invites reach the limit" do
      admin = super_admin_fixture()
      {user, organization} = workspace_fixture()
      opts = [actor: user, tenant: organization]
      Accounts.set_plan_limits!(organization, %{seat_limit: 2}, actor: admin)

      assert {:ok, _} = Accounts.invite(%{email: "one@example.com", role: :member}, opts)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.invite(%{email: "two@example.com", role: :member}, opts)
    end
  end

  describe "super admins" do
    test "see every workspace and act as admin inside it" do
      admin = super_admin_fixture()
      {_user, organization} = workspace_fixture(%{name: "Initrode"})

      assert [%{name: "Initrode", members_count: 1}] =
               Accounts.platform_organizations!(%{query: "initr"}, actor: admin)

      assert [_ | _] = Crm.list_pipelines!(actor: admin, tenant: organization)
    end

    test "regular users can't use platform actions" do
      {user, organization} = workspace_fixture()

      # Reads are filtered to nothing rather than raising.
      assert {:ok, []} = Accounts.platform_organizations(actor: user)
      assert {:error, %Ash.Error.Forbidden{}} = Platform.platform_overview(actor: user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.set_plan_limits(organization, %{seat_limit: 100}, actor: user)

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.set_super_admin(user, true, actor: user)
    end

    test "overview adds up MRR from trialing and active subscriptions" do
      admin = super_admin_fixture()
      {_user, organization} = workspace_fixture()
      plan = plan_fixture(%{price_per_seat: Decimal.new(20)})

      organization.id
      |> Platform.ensure_subscription!(actor: admin)
      |> Platform.change_plan!(%{plan_id: plan.id, status: :active}, actor: admin)

      overview = Platform.platform_overview!(actor: admin)
      assert overview.organizations >= 1
      assert Decimal.compare(overview.mrr, Decimal.new(20)) in [:gt, :eq]
    end

    test "workspace admins can request a plan; the request is logged" do
      admin = super_admin_fixture()
      {user, organization} = workspace_fixture()
      plan = plan_fixture(%{name: "Scale"})

      Platform.request_plan!(plan.id, actor: user, tenant: organization)

      assert [event] =
               Platform.list_audit_events!(%{organization_id: organization.id}, actor: admin)

      assert event.action == :plan_requested
      assert event.summary =~ "Scale"
    end
  end
end
