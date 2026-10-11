defmodule Zippiker.Assistant.ProvidersTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Assistant, Parties}
  alias Zippiker.Assistant.{LLM, OpenAICompatible}
  alias Zippiker.FakeClaude

  setup do
    {owner, organization} = workspace_fixture()
    %{opts: [actor: owner, tenant: organization], organization: organization}
  end

  test "a workspace key is encrypted and only its hint is shown", %{
    opts: opts,
    organization: organization
  } do
    settings =
      Assistant.configure_ai!(
        %{provider: :openai, model: "gpt-5", api_key: "sk-test-secret-1234"},
        opts
      )

    assert settings.key_hint == "1234"
    refute settings.encrypted_api_key =~ "secret"

    cfg = LLM.resolve(organization)
    assert cfg.source == :workspace
    assert cfg.api_key == "sk-test-secret-1234"
    assert cfg.base_url == "https://api.openai.com/v1"

    # Saving without a key keeps the stored one.
    Assistant.configure_ai!(%{provider: :xai, model: "grok-4"}, opts)
    cfg = LLM.resolve(organization)
    assert {cfg.provider, cfg.api_key} == {:xai, "sk-test-secret-1234"}

    {:ok, current} = Assistant.ai_settings(opts)
    Assistant.remove_ai_key!(current, opts)
    assert LLM.resolve(organization).source == :server
  end

  test "other providers need a safe base URL", %{opts: opts} do
    assert {:error, _} =
             Assistant.configure_ai(
               %{provider: :custom, model: "llama", api_key: "k", base_url: "http://10.0.0.5"},
               opts
             )

    assert {:ok, _} =
             Assistant.configure_ai(
               %{
                 provider: :custom,
                 model: "llama",
                 api_key: "k",
                 base_url: "http://localhost:11434/v1"
               },
               opts
             )
  end

  test "members without the permission can't change the provider", %{organization: organization} do
    member = member_fixture(organization)

    assert {:error, %Ash.Error.Forbidden{}} =
             Assistant.configure_ai(
               %{provider: :openai, model: "gpt-5", api_key: "sk-x"},
               actor: member,
               tenant: organization
             )
  end

  test "OpenAI-compatible providers get translated requests and replies", %{opts: opts} do
    Parties.create_party!(%{kind: :organization, name: "Globex", roles: [:customer]}, opts)

    Assistant.configure_ai!(
      %{provider: :gemini, model: "gemini-2.5-pro", api_key: "AIza-test"},
      opts
    )

    FakeClaude.script([
      %{
        "choices" => [
          %{
            "finish_reason" => "tool_calls",
            "message" => %{
              "content" => nil,
              "tool_calls" => [
                %{
                  "id" => "call_1",
                  "type" => "function",
                  "function" => %{
                    "name" => "search_records",
                    "arguments" => ~s({"type":"customers","query":"Globex"})
                  }
                }
              ]
            }
          }
        ]
      },
      %{
        "choices" => [
          %{"finish_reason" => "stop", "message" => %{"content" => "Globex is a customer."}}
        ]
      }
    ])

    result = Assistant.assistant_reply!([], "Is Globex a customer?", opts)
    assert result.status == "done"

    assert %{"content" => [%{"type" => "text", "text" => "Globex is a customer."}]} =
             List.last(result.history)

    [{headers, first}, {_h, second}] = FakeClaude.requests()
    assert {"authorization", "Bearer AIza-test"} in headers
    assert first["model"] == "gemini-2.5-pro"
    assert hd(first["messages"])["role"] == "system"

    assert %{"type" => "function", "function" => %{"name" => "search_records"}} =
             hd(first["tools"])

    [_system, _user, assistant, tool] = second["messages"]

    assert [%{"id" => "call_1", "function" => %{"name" => "search_records"}}] =
             assistant["tool_calls"]

    assert tool["role"] == "tool" and tool["tool_call_id"] == "call_1"
    assert tool["content"] =~ "Globex"
  end

  test "replies without tool ids still get one" do
    response =
      OpenAICompatible.from_openai(%{
        "choices" => [
          %{
            "finish_reason" => "tool_calls",
            "message" => %{
              "tool_calls" => [%{"function" => %{"name" => "list_reports", "arguments" => "{}"}}]
            }
          }
        ]
      })

    assert %{"stop_reason" => "tool_use", "content" => [%{"id" => "call_0_" <> _}]} = response
  end
end
