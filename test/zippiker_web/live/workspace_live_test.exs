defmodule ZippikerWeb.WorkspaceLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Crm, Extensibility, Parties}

  describe "access" do
    test "anonymous visitors are sent to sign in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/")
    end

    test "users without a workspace are onboarded", %{conn: conn} do
      user = Zippiker.Fixtures.user_fixture()

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      assert {:error, {:redirect, %{to: "/onboarding"}}} = live(conn, ~p"/")

      {:ok, view, _html} = live(conn, ~p"/onboarding")

      view
      |> form("#onboarding-form", %{name: "Ada", workspace: "Analytical", currency: "EUR"})
      |> render_submit()

      conn = follow_trigger_action(form(view, "#switch-form"), conn)
      assert redirected_to(conn) == "/"

      assert [%{organization: %{name: "Analytical", currency: "EUR"}}] =
               Zippiker.Accounts.list_my_memberships!(actor: user, load: [:organization])
    end
  end

  describe "pages" do
    setup :register_and_log_in_user

    test "every main page renders", %{conn: conn} do
      for path <-
            ~w(/ /leads /deals /contacts /companies /tasks /settings/custom-fields /settings/pipeline /settings/workspace) do
        assert {:ok, _view, _html} = live(conn, path)
      end
    end

    test "dashboard shows KPIs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#stat-pipeline")
      assert has_element?(view, "#stat-win-rate")
    end
  end

  describe "contacts with custom fields" do
    setup :register_and_log_in_user

    test "creates a contact including a custom field value", %{conn: conn, opts: opts} do
      Extensibility.create_custom_field!(
        %{entity: :person, label: "Tier", type: :select, options: ["Gold", "Silver"]},
        opts
      )

      {:ok, view, _html} = live(conn, ~p"/contacts/new")
      assert has_element?(view, "#party-form select[name='party[custom_fields][tier]']")

      view
      |> form("#party-form",
        party: %{first_name: "Ada", last_name: "Lovelace", custom_fields: %{tier: "Gold"}}
      )
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, show, _html} = live(conn, path)
      assert render(show) =~ "Ada Lovelace"
      assert [%{custom_fields: %{"tier" => "Gold"}}] = Parties.list_parties!(:person, opts)
    end

    test "admins define custom fields from settings", %{conn: conn, opts: opts} do
      {:ok, view, _html} = live(conn, ~p"/settings/custom-fields/new?entity=deal")

      view
      |> form("#field-form", field: %{label: "Seats", type: "number"})
      |> render_submit()

      assert [%{key: "seats", type: :number}] = Extensibility.list_custom_fields!(:deal, opts)
    end
  end

  describe "leads and deals" do
    setup :register_and_log_in_user

    test "converts a lead into a contact and a deal", %{conn: conn, opts: opts} do
      lead = Crm.create_lead!(%{first_name: "Grace", company_name: "Navy"}, opts)

      {:ok, view, _html} = live(conn, ~p"/leads/#{lead}/convert")

      assert {:error, {:live_redirect, %{to: "/contacts/" <> _}}} =
               view
               |> form("#convert-form", convert: %{"create_deal?" => "true", deal_amount: "1200"})
               |> render_submit()

      assert [%{title: "Navy deal"}] = Crm.list_deals!(opts)
    end

    test "moves a deal on the board", %{conn: conn, opts: opts, organization: organization} do
      deal =
        Crm.create_deal!(
          %{title: "Drag me", stage_id: Zippiker.Fixtures.stage(organization, "Qualified").id},
          opts
        )

      won = Zippiker.Fixtures.stage(organization, "Won")
      {:ok, view, _html} = live(conn, ~p"/deals")
      assert has_element?(view, "#stage-#{deal.stage_id} [data-deal-id='#{deal.id}']")

      render_hook(view, "move", %{"id" => deal.id, "stage_id" => won.id, "position" => 0})

      assert has_element?(view, "#stage-#{won.id} [data-deal-id='#{deal.id}']")
      assert Crm.get_deal!(deal.id, opts).status == :won
    end

    test "logs activity and tasks on a deal", %{
      conn: conn,
      opts: opts,
      organization: organization
    } do
      deal =
        Crm.create_deal!(
          %{title: "Timeline", stage_id: Zippiker.Fixtures.stage(organization, "Proposal").id},
          opts
        )

      {:ok, view, _html} = live(conn, ~p"/deals/#{deal}")

      view
      |> form("#activity-activity-form", activity: %{body: "Sent the proposal"})
      |> render_submit()

      assert render(view) =~ "Sent the proposal"

      assert [%{body: "Sent the proposal", kind: :note}] =
               Crm.timeline!(%{deal_id: deal.id}, opts)
    end
  end
end
