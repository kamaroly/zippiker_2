defmodule ZippikerWeb.ReportLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Catalog, Parties, Sales}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)

    %{
      customer_id: customer.id,
      lines: [%{description: "Consulting", quantity: "2", unit_price: "100"}]
    }
    |> Sales.create_invoice!(opts)
    |> Sales.issue_invoice!(opts)

    Catalog.create_product!(%{name: "Widget", unit_price: "10"}, opts)
    :ok
  end

  test "the report center lists reports by group and searches them", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reports")

    assert has_element?(view, "#report-popular")
    assert has_element?(view, "#report-group-receivables")
    assert has_element?(view, "#report-link-receivables-ar-ageing-summary")

    view |> form("#report-search", query: "ageing") |> render_change()
    assert has_element?(view, "#report-link-receivables-ar-ageing-summary")
    refute has_element?(view, "#report-group-tax")

    view |> form("#report-search", query: "zzzz") |> render_change()
    assert has_element?(view, "#report-no-match")
  end

  test "every report page renders", %{conn: conn, opts: opts} do
    for %{key: key} <- Zippiker.Reporting.report_catalog!(opts) do
      {:ok, view, _html} = live(conn, ~p"/reports/#{key}")
      assert has_element?(view, "#report-#{key}")
      assert has_element?(view, "#report-table")
    end
  end

  test "changing the period re-runs the report", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reports/invoice-list")
    assert has_element?(view, "#report-table td", "Globex")

    view |> form("#report-filters", period: "last_year") |> render_change()
    assert_patch(view, ~p"/reports/invoice-list?period=last_year")
    assert has_element?(view, "#report-table-empty")

    {:ok, view, _html} = live(conn, ~p"/reports/ar-ageing-summary?to=2000-01-01")
    assert has_element?(view, "#report-table-empty")
  end

  test "unknown reports go back to the report center", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/reports"}}} = live(conn, ~p"/reports/nope")
  end

  test "reports export as CSV", %{conn: conn} do
    conn = get(conn, ~p"/reports/invoice-list/export?period=this_year")
    assert response_content_type(conn, :csv) =~ "text/csv"
    body = response(conn, 200)
    assert body =~ "Date,Number,Customer"
    assert body =~ "Globex"
  end

  test "reports show in the command search", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#command-palette-items a[href='/reports/profit-and-loss']")
  end
end
