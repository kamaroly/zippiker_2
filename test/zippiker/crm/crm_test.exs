defmodule Zippiker.CrmTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Crm, Parties}

  setup do
    {user, organization} = workspace_fixture()
    %{user: user, organization: organization, opts: [actor: user, tenant: organization]}
  end

  describe "tenancy" do
    test "records are invisible to other organizations", %{opts: opts} do
      Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
      {other_user, other_org} = workspace_fixture()

      assert [] = Parties.list_parties!(:organization, actor: other_user, tenant: other_org)
    end

    test "non-members are forbidden", %{organization: organization} do
      outsider = Ash.load!(user_fixture(), :memberships, authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               Parties.create_party(%{kind: :organization, name: "X"},
                 actor: outsider,
                 tenant: organization
               )
    end
  end

  describe "deals" do
    test "moving to a won stage closes the deal and marks customers", %{opts: opts} = ctx do
      company = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)

      deal =
        Crm.create_deal!(
          %{
            title: "Globex renewal",
            amount: Money.new!(:USD, 5000),
            stage_id: stage(ctx.organization, "Proposal").id,
            company_id: company.id
          },
          opts
        )

      assert deal.status == :open
      assert is_nil(deal.closed_at)

      deal = Crm.move_deal!(deal, stage(ctx.organization, "Won").id, 1.0, opts)
      assert deal.status == :won
      assert deal.closed_at

      assert :customer in Parties.get_party!(company.id, opts).roles

      deal = Crm.move_deal!(deal, stage(ctx.organization, "Discovery").id, 1.0, opts)
      assert deal.status == :open
      assert is_nil(deal.closed_at)
    end

    test "amounts must be in the organization currency", %{opts: opts} = ctx do
      assert {:error, %Ash.Error.Invalid{}} =
               Crm.create_deal(
                 %{
                   title: "Euro deal",
                   amount: Money.new!(:EUR, 10),
                   stage_id: stage(ctx.organization, "Proposal").id
                 },
                 opts
               )
    end
  end

  describe "leads" do
    test "conversion creates company, contact and deal and moves history", %{opts: opts} do
      lead =
        Crm.create_lead!(
          %{first_name: "Grace", last_name: "Hopper", company_name: "Navy", email: "g@navy.mil"},
          opts
        )

      Crm.log_activity!(%{kind: :call, body: "Intro call", lead_id: lead.id}, opts)
      existing = Parties.create_party!(%{kind: :organization, name: "navy"}, opts)

      lead = Crm.convert_lead!(lead, %{deal_amount: Decimal.new("2500")}, opts)

      assert lead.status == :converted
      assert lead.company_id == existing.id

      person = Parties.get_party!(lead.party_id, opts)
      assert person.name == "Grace Hopper"
      assert person.employer_id == existing.id

      [deal] = Crm.list_deals!(%{party_id: person.id}, opts)
      assert deal.title == "Navy deal"
      assert Money.equal?(deal.amount, Money.new!(:USD, 2500))

      assert [%{body: "Intro call"}] = Crm.timeline!(%{party_id: existing.id}, opts)
      assert {:error, _} = Crm.convert_lead(lead, %{}, opts)
    end
  end

  describe "dashboard" do
    test "summarises pipeline, wins and agenda", %{opts: opts} = ctx do
      for {title, amount, stage} <- [
            {"A", 1000, "Proposal"},
            {"B", 3000, "Negotiation"},
            {"C", 500, "Won"}
          ] do
        Crm.create_deal!(
          %{
            title: title,
            amount: Money.new!(:USD, amount),
            stage_id: stage(ctx.organization, stage).id
          },
          opts
        )
      end

      Crm.create_task!(%{title: "Call back", due_on: Date.utc_today()}, opts)
      Crm.create_lead!(%{first_name: "New"}, opts)

      summary = Crm.dashboard_summary!(opts)

      assert Money.equal?(summary.open_value, Money.new!(:USD, 4000))
      assert Money.equal?(summary.weighted_value, Money.new!(:USD, 2750))
      assert Money.equal?(summary.won_this_month, Money.new!(:USD, 500))
      assert summary.win_rate == 100
      assert summary.new_leads == 1
      assert [%{title: "Call back"}] = summary.agenda
      assert Money.equal?(List.last(summary.revenue_trend).amount, Money.new!(:USD, 500))
    end
  end
end
