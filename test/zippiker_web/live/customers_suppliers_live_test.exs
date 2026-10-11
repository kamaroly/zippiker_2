defmodule ZippikerWeb.CustomersSuppliersLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.Parties

  setup :register_and_log_in_user

  test "customers list people and companies with the customer role", %{conn: conn, opts: opts} do
    Parties.create_party!(%{kind: :organization, name: "Globex", roles: [:customer]}, opts)

    Parties.create_party!(
      %{kind: :person, first_name: "Ann", last_name: "Lee", roles: [:customer]},
      opts
    )

    Parties.create_party!(%{kind: :organization, name: "Acme Supplies", roles: [:supplier]}, opts)

    {:ok, view, _html} = live(conn, ~p"/customers")
    assert has_element?(view, "#parties", "Globex")
    assert has_element?(view, "#parties", "Ann Lee")
    refute has_element?(view, "#parties", "Acme Supplies")
    assert has_element?(view, "#module-tabs #tab-customers.border-brand")

    {:ok, view, _html} = live(conn, ~p"/customers?type=person")
    refute has_element?(view, "#parties", "Globex")

    {:ok, view, _html} = live(conn, ~p"/suppliers")
    assert has_element?(view, "#parties", "Acme Supplies")
    refute has_element?(view, "#parties", "Globex")
  end

  test "adding a supplier marks it as one", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/suppliers/new?kind=organization")

    view |> form("#party-form", party: %{name: "Paper Co"}) |> render_submit()

    supplier = Enum.find(Parties.list_parties!(:organization, opts), &(&1.name == "Paper Co"))
    assert :supplier in supplier.roles
  end

  test "users and invitations live under Settings → Users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/users")
    assert has_element?(view, "#members")
    assert has_element?(view, "#invite-form")

    {:ok, view, _html} = live(conn, ~p"/settings/workspace")
    refute has_element?(view, "#members")
  end
end
