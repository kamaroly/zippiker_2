defmodule ZippikerWeb.AssistantLiveTest do
  # Turns run in a separate process, so the Claude stub is shared.
  use ZippikerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Zippiker.{Crm, Parties}
  alias Zippiker.FakeClaude

  setup :register_and_log_in_user
  setup :set_req_test_to_shared

  defp set_req_test_to_shared(context), do: Req.Test.set_req_test_to_shared(context)

  test "asks a question and shows the answer and what was looked up", %{conn: conn, opts: opts} do
    Parties.create_party!(%{kind: :organization, name: "Globex", roles: [:customer]}, opts)

    FakeClaude.script([
      FakeClaude.tool("t1", "search_records", %{"type" => "customers", "query" => "Globex"}),
      FakeClaude.text("Yes, Globex is a customer.")
    ])

    {:ok, view, _html} = live(conn, ~p"/assistant")
    assert has_element?(view, "#assistant-empty")

    view |> form("#assistant-form", text: "Is Globex a customer?") |> render_submit()
    render_async(view)

    assert has_element?(view, "#assistant-messages", "Is Globex a customer?")
    assert has_element?(view, "#assistant-messages", "Searched customers for “Globex”")
    assert has_element?(view, "#assistant-messages", "Yes, Globex is a customer.")
  end

  test "approves a proposed task", %{conn: conn, opts: opts} do
    FakeClaude.script([
      FakeClaude.tool("t1", "create_task", %{"title" => "Call Ann"}, "I'll add that."),
      FakeClaude.text("Added.")
    ])

    {:ok, view, _html} = live(conn, ~p"/assistant")
    view |> element("#suggestion-4") |> render_click()
    render_async(view)

    assert has_element?(view, "#assistant-approval", "Create task “Call Ann”")
    view |> element("#approve-actions") |> render_click()
    render_async(view)

    refute has_element?(view, "#assistant-approval")
    assert has_element?(view, "#assistant-messages", "Added.")
    assert [%{title: "Call Ann"}] = Crm.list_tasks!(%{view: :all}, opts)
  end

  test "a question from the command search is sent on open", %{conn: conn} do
    FakeClaude.script([FakeClaude.text("Hello!")])
    {:ok, view, _html} = live(conn, ~p"/assistant?q=hi")
    render_async(view)
    assert has_element?(view, "#assistant-messages", "Hello!")
  end

  test "without an API key it explains how to switch it on", %{conn: conn} do
    config = Application.get_env(:zippiker, Zippiker.Assistant)
    Application.put_env(:zippiker, Zippiker.Assistant, Keyword.put(config, :api_key, nil))
    on_exit(fn -> Application.put_env(:zippiker, Zippiker.Assistant, config) end)

    {:ok, view, _html} = live(conn, ~p"/assistant")
    assert has_element?(view, "#assistant-not-configured")
    assert has_element?(view, "#assistant-setup-help[href='/help/ai-assistant']")
  end

  test "the help article renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/help/ai-assistant")
    assert html =~ "Asking it to do things"
  end
end
