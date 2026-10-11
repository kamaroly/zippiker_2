defmodule ZippikerWeb.PortalLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Parties, Purchasing, Sales}

  setup :register_and_log_in_user

  defp invite(conn, party, email, kind) do
    {:ok, view, _html} =
      live(
        conn,
        if(party.kind == :person, do: ~p"/contacts/#{party}", else: ~p"/companies/#{party}")
      )

    view
    |> form("#portal-invite-form", portal: %{email: email, kind: kind})
    |> render_submit()
  end

  defp claim(user, organization) do
    [access] =
      Accounts.PortalAccess
      |> Ash.read!(tenant: organization.id, authorize?: false)
      |> Enum.filter(&(to_string(&1.email) == to_string(user.email)))

    conn = log_in_user(build_conn(), user)
    conn = get(conn, ~p"/portal/join/#{access.token}")
    assert redirected_to(conn) == "/portal/#{access.id}"
    {recycle(conn), access}
  end

  test "a customer sees their documents and accepts a quote", %{
    conn: conn,
    opts: opts,
    organization: organization
  } do
    customer = Parties.create_party!(%{kind: :organization, name: "Acme Ltd"}, opts)
    other = Parties.create_party!(%{kind: :organization, name: "Other Co"}, opts)
    line = %{description: "Consulting", quantity: "2", unit_price: "100"}

    quote =
      Sales.create_quote!(%{customer_id: customer.id, lines: [line]}, opts)
      |> Sales.send_quote!(opts)

    _draft = Sales.create_quote!(%{customer_id: customer.id, lines: [line]}, opts)

    foreign =
      Sales.create_quote!(%{customer_id: other.id, lines: [line]}, opts)
      |> Sales.send_quote!(opts)

    contact = user_fixture()
    invite(conn, customer, to_string(contact.email), "customer")
    {portal, access} = claim(contact, organization)

    # Portal-only users land in the portal.
    assert {:error, {:redirect, %{to: "/portal"}}} = live(portal, ~p"/dashboard")

    {:ok, view, _html} = live(portal, ~p"/portal/#{access.id}")
    assert has_element?(view, "#portal-quote-list", quote.number)
    # Drafts and other customers' documents stay hidden.
    assert view
           |> element("#portal-quote-list")
           |> render()
           |> then(&(length(String.split(&1, "<li")) - 1)) == 1

    refute has_element?(view, "#portal-quote-list", foreign.number)

    assert {:error, {:live_redirect, %{to: "/portal"}}} =
             live(portal, ~p"/portal/#{access.id}/quote/#{foreign.id}")

    {:ok, view, _html} = live(portal, ~p"/portal/#{access.id}/quote/#{quote.id}")
    view |> element("#accept-quote") |> render_click()
    assert Sales.get_quote!(quote.id, opts).status == :accepted
  end

  test "a supplier prices a request for quotation and acknowledges an order", %{
    conn: conn,
    opts: opts,
    organization: organization
  } do
    supplier = Parties.create_party!(%{kind: :organization, name: "Steel Co"}, opts)
    line = %{description: "Steel bars", quantity: "10", unit_price: "0"}

    rfq =
      Purchasing.create_rfq!(%{supplier_id: supplier.id, lines: [line]}, opts)
      |> Purchasing.send_rfq!(opts)

    order =
      Purchasing.create_purchase_order!(
        %{supplier_id: supplier.id, lines: [%{line | unit_price: "5"}]},
        opts
      )
      |> Purchasing.place_purchase_order!(opts)

    contact = user_fixture()
    invite(conn, supplier, to_string(contact.email), "supplier")
    {portal, access} = claim(contact, organization)

    {:ok, view, _html} = live(portal, ~p"/portal/#{access.id}/rfq/#{rfq.id}")
    [rfq_line] = Purchasing.get_rfq!(rfq.id, opts ++ [load: [:lines]]).lines

    view
    |> form("#rfq-prices-form", %{"prices" => %{rfq_line.id => "7.5"}, "reference" => "Q-881"})
    |> render_submit()

    priced = Purchasing.get_rfq!(rfq.id, opts ++ [load: [:lines]])
    assert priced.status == :quoted
    assert Decimal.eq?(hd(priced.lines).unit_price, "7.5")

    {:ok, view, _html} = live(portal, ~p"/portal/#{access.id}/purchase_order/#{order.id}")
    view |> element("#acknowledge-order") |> render_click()
    assert Purchasing.get_purchase_order!(order.id, opts).acknowledged_at
  end

  test "invitations are for the invited email only", %{
    conn: conn,
    opts: opts,
    organization: organization
  } do
    customer = Parties.create_party!(%{kind: :organization, name: "Acme Ltd"}, opts)
    invite(conn, customer, "someone@acme.test", "customer")
    [access] = Ash.read!(Accounts.PortalAccess, tenant: organization.id, authorize?: false)

    stranger = log_in_user(build_conn(), user_fixture())
    conn = get(stranger, ~p"/portal/join/#{access.token}")
    assert redirected_to(conn) == "/"
    assert Ash.get!(Accounts.PortalAccess, access.id, authorize?: false).status == :invited
  end
end
