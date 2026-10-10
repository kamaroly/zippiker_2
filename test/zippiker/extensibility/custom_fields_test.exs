defmodule Zippiker.Extensibility.CustomFieldsTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Extensibility, Parties}

  setup do
    {user, organization} = workspace_fixture()
    %{user: user, opts: [actor: user, tenant: organization], organization: organization}
  end

  defp define!(attrs, opts), do: Extensibility.create_custom_field!(attrs, opts)

  test "derives a stable key from the label", %{opts: opts} do
    field = define!(%{entity: :person, label: "Annual Budget (USD)", type: :number}, opts)
    assert field.key == "annual_budget_usd"
  end

  test "select fields need options", %{opts: opts} do
    assert {:error, %Ash.Error.Invalid{}} =
             Extensibility.create_custom_field(
               %{entity: :deal, label: "Tier", type: :select},
               opts
             )
  end

  test "casts values by type and drops unknown keys", %{opts: opts} do
    define!(%{entity: :person, label: "Budget", type: :number}, opts)
    define!(%{entity: :person, label: "VIP", type: :boolean}, opts)
    define!(%{entity: :person, label: "Tier", type: :select, options: ["Gold", "Silver"]}, opts)

    person =
      Parties.create_party!(
        %{
          kind: :person,
          first_name: "Ada",
          custom_fields: %{"budget" => "1,500", "vip" => "true", "tier" => "Gold", "hack" => "x"}
        },
        opts
      )

    assert person.custom_fields == %{"budget" => 1500, "vip" => true, "tier" => "Gold"}
  end

  test "rejects invalid and missing required values", %{opts: opts} do
    define!(%{entity: :person, label: "Tier", type: :select, options: ["Gold"]}, opts)
    define!(%{entity: :person, label: "Region", type: :text, required?: true}, opts)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Parties.create_party(
               %{
                 kind: :person,
                 first_name: "Ada",
                 custom_fields: %{"tier" => "Bronze", "region" => ""}
               },
               opts
             )

    messages = Enum.map(errors, & &1.message)
    assert "Region is required" in messages
    assert Enum.any?(messages, &(&1 =~ "Tier must be one of"))
  end

  test "definitions are scoped per entity and per organization", %{opts: opts} do
    define!(%{entity: :organization, label: "Employees", type: :number}, opts)

    person =
      Parties.create_party!(
        %{kind: :person, first_name: "Ada", custom_fields: %{"employees" => "5"}},
        opts
      )

    assert person.custom_fields == %{}

    {other_user, other_org} = workspace_fixture()

    assert [] ==
             Extensibility.list_custom_fields!(:organization,
               actor: other_user,
               tenant: other_org
             )
  end

  test "partial updates keep values of fields that were not submitted", %{opts: opts} do
    define!(%{entity: :deal, label: "Source", type: :text}, opts)
    define!(%{entity: :deal, label: "Seats", type: :number}, opts)

    deal =
      Zippiker.Crm.create_deal!(
        %{
          title: "Big one",
          stage_id: stage(opts[:tenant], "Discovery").id,
          custom_fields: %{"source" => "Webinar", "seats" => "10"}
        },
        opts
      )

    deal = Zippiker.Crm.update_deal!(deal, %{custom_fields: %{"seats" => "12"}}, opts)
    assert deal.custom_fields == %{"source" => "Webinar", "seats" => 12}
  end

  test "only admins manage definitions", %{organization: organization} do
    member = member_fixture(organization)

    assert {:error, %Ash.Error.Forbidden{}} =
             Extensibility.create_custom_field(
               %{entity: :deal, label: "Nope", type: :text},
               actor: member,
               tenant: organization
             )
  end
end
