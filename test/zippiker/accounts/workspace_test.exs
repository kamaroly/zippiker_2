defmodule Zippiker.Accounts.WorkspaceTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Extensibility, Parties}

  setup do
    {user, organization} = workspace_fixture()
    %{user: user, organization: organization, opts: [actor: user, tenant: organization]}
  end

  test "new workspaces get a default legal entity", %{opts: opts, organization: organization} do
    entity = Accounts.default_legal_entity!(opts)
    assert entity.default?
    assert entity.name == organization.name
    assert entity.currency == "USD"
    assert [%{id: id}] = Accounts.list_legal_entities!(opts)
    assert id == entity.id
  end

  test "invitations are emailed and accepted by the invitee", %{
    opts: opts,
    organization: organization
  } do
    invitation = Accounts.invite!(%{email: "new@example.com", role: :admin}, opts)
    assert_received {:email, %{to: [{_, "new@example.com"}], subject: subject}}
    assert subject =~ "invited you to"

    stranger = user_fixture()
    assert {:error, _} = Accounts.accept_invitation(invitation, actor: stranger)

    invitee = user_fixture(%{email: "new@example.com"})
    assert [_] = Accounts.list_my_invitations!(actor: invitee)
    Accounts.accept_invitation!(invitation, actor: invitee)

    assert [%{organization_id: org_id, role: :admin}] =
             Accounts.list_my_memberships!(actor: invitee)

    assert org_id == organization.id

    assert {:error, _} =
             Accounts.accept_invitation(Ash.reload!(invitation, authorize?: false),
               actor: invitee
             )
  end

  test "the owner can't be removed", %{user: user, organization: organization} do
    [owner] = Accounts.list_members!(organization.id, actor: user)
    assert {:error, _} = Accounts.remove_member(owner, actor: user, tenant: organization)
  end

  test "lists filter by custom field values", %{opts: opts} do
    Extensibility.create_custom_field!(
      %{entity: :organization, label: "Tier", type: :select, options: ["Gold", "Silver"]},
      opts
    )

    Extensibility.create_custom_field!(
      %{entity: :organization, label: "Regions", type: :multi_select, options: ["EU", "US"]},
      opts
    )

    Parties.create_party!(
      %{
        kind: :organization,
        name: "A",
        custom_fields: %{"tier" => "Gold", "regions" => ["EU", "US"]}
      },
      opts
    )

    Parties.create_party!(
      %{
        kind: :organization,
        name: "B",
        custom_fields: %{"tier" => "Silver", "regions" => ["US"]}
      },
      opts
    )

    assert [%{name: "A"}] =
             Parties.list_parties!(:organization, %{custom_fields: %{"tier" => "Gold"}}, opts)

    assert [%{name: "A"}] =
             Parties.list_parties!(:organization, %{custom_fields: %{"regions" => "EU"}}, opts)

    assert 2 =
             length(
               Parties.list_parties!(
                 :organization,
                 %{custom_fields: %{"regions" => "US", "nope" => "x"}},
                 opts
               )
             )
  end
end
