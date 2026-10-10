defmodule ZippikerWeb.AccountingLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Accounting, Accounts}

  setup :register_and_log_in_user

  defp account(opts, key), do: Enum.find(Accounting.list_accounts!(opts), &(&1.system_key == key))

  test "an admin sets up the books from the overview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/accounting")
    assert has_element?(view, "#accounting-setup")

    view |> element("#setup-books") |> render_click()

    assert has_element?(view, "#stat-cash")
    assert has_element?(view, "#record-expense")
  end

  test "every accounting page renders", %{conn: conn, opts: opts} do
    Accounting.setup_books!(opts)
    cash = account(opts, :cash)

    for path <- [
          ~p"/accounting",
          ~p"/accounting/accounts",
          ~p"/accounting/accounts/#{cash}",
          ~p"/accounting/journal",
          ~p"/accounting/journal/new",
          ~p"/accounting/reports",
          ~p"/accounting/reports?report=balance_sheet",
          ~p"/accounting/reports?report=trial_balance"
        ] do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "records an expense from the overview", %{conn: conn, opts: opts} do
    Accounting.setup_books!(opts)
    rent = Enum.find(Accounting.list_accounts!(opts), &(&1.code == "6100"))

    {:ok, view, _html} = live(conn, ~p"/accounting/expense")

    view
    |> form("#expense-form",
      expense: %{
        memo: "Office rent",
        amount: "250",
        expense_account_id: rent.id,
        paid_from_account_id: account(opts, :bank).id
      }
    )
    |> render_submit()

    assert_patch(view, ~p"/accounting")
    assert Decimal.eq?(account(opts, :bank).balance, Decimal.new(-250))
    assert has_element?(view, "#recent-entries", "Office rent")
  end

  test "posts a balanced manual entry, then reverses it", %{conn: conn, opts: opts} do
    Accounting.setup_books!(opts)
    bank = account(opts, :bank)
    equity = account(opts, :equity)

    {:ok, view, _html} = live(conn, ~p"/accounting/journal/new")

    params = %{
      memo: "Owner investment",
      lines: %{
        "0" => %{account_id: bank.id, debit: "1000", credit: ""},
        "1" => %{account_id: equity.id, debit: "", credit: "900"}
      }
    }

    view |> form("#entry-form", entry: params) |> render_change()
    refute has_element?(view, "#balance-indicator", "Balanced")

    params = put_in(params, [:lines, "1", :credit], "1000")
    view |> form("#entry-form", entry: params) |> render_change()
    assert has_element?(view, "#balance-indicator", "Balanced")

    {:ok, entry_view, _html} =
      view |> form("#entry-form", entry: params) |> render_submit() |> follow_redirect(conn)

    assert has_element?(entry_view, "#entry-lines", "Owner's equity")
    assert Decimal.eq?(account(opts, :bank).balance, Decimal.new(1000))

    {:ok, _reversal_view, _html} =
      entry_view |> element("#reverse-entry") |> render_click() |> follow_redirect(conn)

    assert Decimal.eq?(account(opts, :bank).balance, Decimal.new(0))
  end

  test "adds an account to the chart", %{conn: conn, opts: opts} do
    Accounting.setup_books!(opts)
    {:ok, view, _html} = live(conn, ~p"/accounting/accounts/new")

    view
    |> form("#account-form", account: %{code: "6150", name: "Insurance", type: "expense"})
    |> render_submit()

    assert_patch(view, ~p"/accounting/accounts")
    assert has_element?(view, "#accounts-expense", "Insurance")
  end

  test "a disabled module is hidden and its pages are refused", %{
    conn: conn,
    organization: organization
  } do
    Accounts.set_plan_limits!(organization, %{enabled_modules: [:crm, :sales]}, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#sidebar a[href='/accounting']")
    assert has_element?(view, "#sidebar a[href='/invoices']")

    assert {:error, {:redirect, %{to: "/", flash: %{"error" => message}}}} =
             live(conn, ~p"/accounting")

    assert message =~ "Accounting"
  end
end
