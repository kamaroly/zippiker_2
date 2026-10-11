defmodule ZippikerWeb.PlatformWorkspaceCreateTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.Accounts

  setup %{conn: conn} do
    admin = super_admin_fixture()
    %{conn: log_in_user(conn, admin), admin: admin}
  end

  defp create(conn, params) do
    {:ok, view, _html} = live(conn, ~p"/platform/teams")
    view |> element("#new-workspace") |> render_click()
    view |> form("#workspace-form", workspace: params) |> render_submit()
  end

  defp organization(name) do
    Zippiker.Accounts.Organization
    |> Ash.read!(authorize?: false)
    |> Enum.find(&(&1.name == name))
  end

  test "an existing user becomes the owner", %{conn: conn} do
    owner = user_fixture()
    create(conn, %{name: "Umbrella", owner_email: to_string(owner.email), currency: "KES"})

    team = organization("Umbrella")
    assert team.currency == "KES"
    [membership] = Accounts.list_members!(team.id, authorize?: false)
    assert membership.user_id == owner.id
    assert membership.role == :owner
    assert length(Accounts.list_roles!(tenant: team, authorize?: false)) > 0
  end

  test "a new person is invited and becomes the owner on accepting", %{conn: conn} do
    create(conn, %{name: "Hooli", owner_email: "gavin@hooli.example"})

    team = organization("Hooli")
    assert Accounts.list_members!(team.id, authorize?: false) == []
    [invitation] = Accounts.list_pending_invitations!(tenant: team, authorize?: false)

    gavin = user_fixture(%{email: "gavin@hooli.example"})
    Accounts.accept_invitation!(invitation, actor: gavin)

    [membership] = Accounts.list_members!(team.id, authorize?: false)
    assert membership.role == :owner
  end

  test "regular users can't create workspaces for others" do
    {user, _team} = workspace_fixture()

    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.platform_create_organization(
               %{name: "Sneaky", currency: "USD", owner_email: "x@example.com"},
               actor: user
             )
  end
end
