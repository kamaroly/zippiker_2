defmodule ZippikerWeb.HelpLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "lists the guides and filters them", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/help")

    for article <- ZippikerWeb.HelpArticles.articles() do
      assert has_element?(view, "#help-#{article.slug}")
    end

    view |> element("#help-search") |> render_change(%{q: "invoice"})
    assert has_element?(view, "#help-quotes-and-invoices")
    refute has_element?(view, "#help-custom-fields")
  end

  test "every article renders", %{conn: conn} do
    for article <- ZippikerWeb.HelpArticles.articles() do
      {:ok, view, _html} = live(conn, ~p"/help/#{article.slug}")
      assert has_element?(view, "#article-#{article.slug}")
    end
  end

  test "unknown articles go back to the index", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/help"}}} = live(conn, ~p"/help/nope")
  end
end
