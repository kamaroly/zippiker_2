defmodule ZippikerWeb.ChangeRequestsLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Catalog, Workflow}

  setup :register_and_log_in_user

  test "maker-checker: turned on in settings, a held edit, the checker applies it", %{
    conn: conn,
    organization: organization,
    opts: opts
  } do
    product = Catalog.create_product!(%{name: "Widget", unit_price: "10"}, opts)
    checker = member_fixture(organization, :admin)

    {:ok, view, _html} = live(conn, ~p"/settings/workspace")

    view
    |> form("#maker-checker-form",
      maker_checker: %{enabled: "true", scopes: ["", "products"]}
    )
    |> render_submit()

    # The owner edits a product: held, not applied.
    {:ok, view, _html} = live(conn, ~p"/products/#{product}/edit")

    view
    |> form("#product-form", product: %{unit_price: "15"})
    |> render_submit()

    assert render(view) =~ "change request CR-"
    assert Decimal.eq?(Catalog.get_product!(product.id, opts).unit_price, 10)

    [request] = Workflow.list_change_requests!(%{}, opts)

    # The checker sees it in their inbox and approves it.
    checker_conn = log_in_user(build_conn(), checker)
    {:ok, inbox, _html} = live(checker_conn, ~p"/approvals")
    assert has_element?(inbox, "a[href='/approvals/changes/#{request.id}']")

    {:ok, page, _html} = live(checker_conn, ~p"/approvals/changes/#{request.id}")
    assert has_element?(page, "#change-diff", "15")
    render_submit(page, "decide", %{"decision" => "approve", "comment" => ""})

    assert Workflow.get_change_request!(request.id, opts).status == :applied
    assert Decimal.eq?(Catalog.get_product!(product.id, opts).unit_price, 15)
    assert {:ok, _list, _html} = live(conn, ~p"/approvals/changes")
  end
end
