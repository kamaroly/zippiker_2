defmodule ZippikerWeb.AiSettingsLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.Assistant

  setup :register_and_log_in_user

  test "picks a provider, saves the key and shows only its hint", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/settings/ai")

    view
    |> form("#ai-form", ai: %{provider: "xai"})
    |> render_change(%{"_target" => ["ai", "provider"]})

    assert has_element?(view, "input[name='ai[model]'][value='grok-4']")

    view
    |> form("#ai-form", ai: %{provider: "xai", model: "grok-4", api_key: "xai-abcdef9876"})
    |> render_submit()

    assert has_element?(view, "#ai-status", "…9876")
    refute render(view) =~ "xai-abcdef9876"
    assert {:ok, %{provider: :xai, key_hint: "9876"}} = Assistant.ai_settings(opts)
  end
end
