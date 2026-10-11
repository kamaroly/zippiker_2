defmodule Zippiker.Accounts.TeamDomainTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.Accounts
  alias Zippiker.Accounts.Tenant
  alias Zippiker.Accounts.Organization.Changes.AssignDomain

  test "a given domain is normalized and names the schema" do
    domain = "Acme-#{System.unique_integer([:positive])}.Example.com"

    changeset =
      Ash.Changeset.for_create(Accounts.Organization, :create, %{name: "Acme", domain: domain})

    changeset = AssignDomain.change(changeset, [], %{})

    assert Ash.Changeset.get_attribute(changeset, :domain) == String.downcase(domain)

    assert Ash.Changeset.get_attribute(changeset, :schema_name) ==
             domain |> String.downcase() |> String.replace(~r/[.\-]/, "_")
  end

  test "teams without a domain are numbered team_n" do
    user = user_fixture()
    org = Accounts.create_organization!(%{name: "Numbered"}, actor: user)
    assert org.domain =~ ~r/^team_\d+$/

    next = Accounts.create_organization!(%{name: "Next"}, actor: user)
    [_, a] = String.split(org.domain, "_")
    [_, b] = String.split(next.domain, "_")
    assert String.to_integer(b) > String.to_integer(a)
  end

  test "invalid, reserved and taken domains are refused" do
    user = user_fixture()

    for domain <- ["1acme", "a", "has space.com", "public", "pg_x", "zippiker"] do
      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.create_organization(%{name: "Bad", domain: domain}, actor: user)
    end

    domain = "taken-#{System.unique_integer([:positive])}.com"
    assert {:ok, _} = Accounts.create_organization(%{name: "First", domain: domain}, actor: user)

    assert {:error, %Ash.Error.Invalid{}} =
             Accounts.create_organization(%{name: "Second", domain: domain}, actor: user)
  end

  test "each team's data lives in its own schema" do
    {owner_a, team_a} = workspace_fixture()
    {owner_b, team_b} = workspace_fixture()

    Zippiker.Parties.create_party!(%{kind: :person, first_name: "Only", last_name: "InA"},
      actor: owner_a,
      tenant: team_a
    )

    assert Tenant.schema(team_a) != Tenant.schema(team_b)
    assert Tenant.organization_id(Tenant.schema(team_a)) == team_a.id
    assert [_] = Zippiker.Parties.list_parties!(:person, %{}, actor: owner_a, tenant: team_a)
    assert [] = Zippiker.Parties.list_parties!(:person, %{}, actor: owner_b, tenant: team_b)

    %{rows: [[count]]} =
      Zippiker.Repo.query!(~s|SELECT count(*) FROM "#{Tenant.schema(team_a)}".parties|)

    assert count == 1
  end
end
