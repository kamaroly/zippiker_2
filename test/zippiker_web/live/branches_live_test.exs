defmodule ZippikerWeb.BranchesLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.Accounts

  setup :register_and_log_in_user

  test "turn on branches, add one, pick it on documents and filter reports", %{
    conn: conn,
    opts: opts
  } do
    {:ok, view, _html} = live(conn, ~p"/settings/branches")
    assert has_element?(view, "#branches", "Head office")
    refute has_element?(view, "#new-branch")

    view |> form("#multi-branch-form", %{multi_branch: "true"}) |> render_change()
    assert has_element?(view, "#new-branch")

    {:ok, view, _html} = live(conn, ~p"/settings/branches/new")
    view |> form("#branch-form", branch: %{name: "Mombasa", code: "mba"}) |> render_submit()
    assert Enum.any?(Accounts.list_branches!(opts), &(&1.code == "MBA"))

    {:ok, invoice_form, _html} = live(conn, ~p"/invoices/new")
    assert has_element?(invoice_form, "#document-form select[name$='[branch_id]']")

    {:ok, reports, _html} = live(conn, ~p"/accounting/reports")
    assert has_element?(reports, "#report-branch")
  end

  test "single-branch teams don't see branch pickers", %{conn: conn} do
    {:ok, invoice_form, _html} = live(conn, ~p"/invoices/new")
    refute has_element?(invoice_form, "#document-form select[name$='[branch_id]']")
  end
end
