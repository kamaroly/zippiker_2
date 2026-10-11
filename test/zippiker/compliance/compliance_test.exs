defmodule Zippiker.ComplianceTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Compliance}

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    entity = Accounts.default_legal_entity!(opts)

    profile =
      Compliance.create_company_profile!(
        %{
          legal_entity_id: entity.id,
          registration_number: "PVT-ABC123",
          incorporation_date: ~D[2019-03-15],
          registered_office: "Westlands, Nairobi",
          kra_pin: "P051234567X"
        },
        opts
      )

    %{opts: opts, profile: profile, organization: organization}
  end

  defp calendar(profile, opts), do: Compliance.filing_calendar!(profile.id, opts)

  test "annual returns are scheduled from the incorporation anniversary, once", %{
    opts: opts,
    profile: profile
  } do
    year = Date.utc_today().year
    returns = Enum.filter(calendar(profile, opts), &(&1.kind == :annual_return))

    assert Enum.map(returns, & &1.title) |> Enum.sort() == [
             "Annual return #{year}",
             "Annual return #{year + 1}"
           ]

    assert Enum.find(returns, &(&1.title == "Annual return #{year}")).due_on ==
             Date.new!(year, 4, 14)

    # Refreshing (daily job) doesn't duplicate them.
    Compliance.refresh_filing_calendars!(%{}, opts)
    assert length(Enum.filter(calendar(profile, opts), &(&1.kind == :annual_return))) == 2
  end

  test "registers feed the filing calendar", %{opts: opts, profile: profile} do
    director =
      Compliance.appoint_officer!(
        %{
          profile_id: profile.id,
          name: "Wanjiku Kamau",
          role: :director,
          appointed_on: Date.add(Date.utc_today(), -30)
        },
        opts
      )

    Compliance.cease_officer!(
      director,
      %{ceased_on: Date.utc_today(), cessation_reason: "Resigned"},
      opts
    )

    ordinary =
      Compliance.create_share_class!(
        %{profile_id: profile.id, name: "Ordinary", nominal_value: "100"},
        opts
      )

    alice = Compliance.add_shareholder!(%{profile_id: profile.id, name: "Alice"}, opts)
    bob = Compliance.add_shareholder!(%{profile_id: profile.id, name: "Bob"}, opts)

    Compliance.allot_shares!(
      %{
        profile_id: profile.id,
        shareholder_id: alice.id,
        share_class_id: ordinary.id,
        quantity: 1000,
        date: ~D[2026-10-02]
      },
      opts
    )

    Compliance.transfer_shares!(
      %{
        profile_id: profile.id,
        from_id: alice.id,
        to_id: bob.id,
        share_class_id: ordinary.id,
        quantity: 400
      },
      opts
    )

    holdings = Map.new(Compliance.member_register!(profile.id, opts), &{&1.name, &1.shares_held})
    assert holdings == %{"Alice" => 600, "Bob" => 400}

    assert {:error, _} =
             Compliance.transfer_shares(
               %{
                 profile_id: profile.id,
                 from_id: bob.id,
                 to_id: alice.id,
                 share_class_id: ordinary.id,
                 quantity: 401
               },
               opts
             )

    Compliance.add_beneficial_owner!(
      %{
        profile_id: profile.id,
        name: "Alice",
        shares_percent: "60",
        became_owner_on: ~D[2026-10-02]
      },
      opts
    )

    Compliance.create_charge!(
      %{
        profile_id: profile.id,
        chargee: "KCB Bank",
        description: "Debenture over all assets",
        amount_secured: "5000000",
        created_on: ~D[2026-10-03]
      },
      opts
    )

    Compliance.create_meeting!(
      %{
        profile_id: profile.id,
        kind: :egm,
        title: "Change of name",
        held_on: ~D[2026-10-06],
        status: :held,
        resolutions: [%{text: "That the company changes its name", kind: :special, passed?: true}]
      },
      opts
    )

    Compliance.update_company_profile!(profile, %{registered_office: "Upper Hill, Nairobi"}, opts)

    kinds = calendar(profile, opts) |> Enum.map(& &1.kind) |> Enum.frequencies()
    assert kinds[:officer_change] == 2
    assert kinds[:allotment_return] == 1
    assert kinds[:beneficial_ownership] == 1
    assert kinds[:charge_registration] == 1
    assert kinds[:resolution_filing] == 1
    assert kinds[:office_change] == 1

    appointed = Enum.find(calendar(profile, opts), &(&1.title =~ "appointed"))
    assert appointed.due_on == Date.add(Date.utc_today(), -16)
    assert appointed.state == :overdue
    assert Enum.find(calendar(profile, opts), &(&1.title =~ "ceased")).state == :due_soon

    done =
      Compliance.complete_compliance_task!(
        appointed,
        %{completed_on: ~D[2026-10-10], reference: "BRS-77"},
        opts
      )

    assert Ash.load!(done, :state, opts).state == :done
  end

  test "public companies get their AGM on the calendar", %{opts: opts, profile: profile} do
    Compliance.update_company_profile!(
      profile,
      %{company_type: :public_limited, year_end_month: 12, year_end_day: 31},
      opts
    )

    year = Date.utc_today().year
    agm = Enum.find(calendar(profile, opts), &(&1.kind == :agm and &1.title =~ "#{year - 1}"))
    assert agm.due_on == Date.new!(year, 6, 30)
  end

  test "members can read, only admins keep the registers", %{
    organization: organization,
    profile: profile
  } do
    member = member_fixture(organization)
    member_opts = [actor: member, tenant: organization]
    assert Compliance.officer_register!(profile.id, member_opts) == []

    assert {:error, %Ash.Error.Forbidden{}} =
             Compliance.appoint_officer(%{profile_id: profile.id, name: "X"}, member_opts)
  end
end
