defmodule Zippiker.Assistant.OpenAICompatible do
  @moduledoc """
  Adapter for providers speaking the OpenAI Chat Completions API: OpenAI,
  xAI Grok, Google Gemini (its OpenAI-compatible endpoint) and others.

  The assistant keeps its conversation in the Anthropic Messages format;
  this module translates the history and tools on the way out, and the
  reply back into `text` / `tool_use` blocks with a matching `stop_reason`.
  """

  alias Zippiker.Assistant.HTTP

  def create(cfg, system, tools, messages) do
    body = %{
      model: cfg.model,
      messages: [%{role: "system", content: system} | Enum.flat_map(messages, &to_openai/1)],
      tools: Enum.map(tools, &tool/1)
    }

    url = String.trim_trailing(cfg.base_url, "/") <> "/chat/completions"

    with {:ok, response} <-
           HTTP.post(url, body, [{"authorization", "Bearer #{cfg.api_key}"}], cfg.label) do
      {:ok, from_openai(response)}
    end
  end

  defp tool(%{name: name, description: description, input_schema: schema}),
    do: %{type: "function", function: %{name: name, description: description, parameters: schema}}

  # History (Anthropic format) -> chat messages.
  def to_openai(%{"role" => "user", "content" => text}) when is_binary(text),
    do: [%{role: "user", content: text}]

  def to_openai(%{"role" => "user", "content" => blocks}) when is_list(blocks) do
    for %{"type" => "tool_result"} = result <- blocks do
      %{role: "tool", tool_call_id: result["tool_use_id"], content: to_string(result["content"])}
    end
  end

  def to_openai(%{"role" => "assistant", "content" => blocks}) when is_list(blocks) do
    text =
      blocks
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map_join("\n", & &1["text"])

    calls =
      for %{"type" => "tool_use"} = call <- blocks do
        %{
          id: call["id"],
          type: "function",
          function: %{name: call["name"], arguments: Jason.encode!(call["input"] || %{})}
        }
      end

    message = %{role: "assistant", content: if(text == "", do: nil, else: text)}
    [if(calls == [], do: message, else: Map.put(message, :tool_calls, calls))]
  end

  def to_openai(_message), do: []

  # Chat completion -> Anthropic-style response.
  def from_openai(%{"choices" => [%{"message" => message} = choice | _]}) do
    text =
      case message["content"] do
        text when is_binary(text) and text != "" -> [%{"type" => "text", "text" => text}]
        _ -> []
      end

    calls =
      for {call, index} <- Enum.with_index(message["tool_calls"] || []) do
        function = call["function"] || %{}

        %{
          "type" => "tool_use",
          "id" => present(call["id"]) || "call_#{index}_#{System.unique_integer([:positive])}",
          "name" => function["name"],
          "input" => arguments(function["arguments"])
        }
      end

    stop =
      cond do
        calls != [] -> "tool_use"
        choice["finish_reason"] == "length" -> "max_tokens"
        choice["finish_reason"] == "content_filter" -> "refusal"
        true -> "end_turn"
      end

    %{"content" => text ++ calls, "stop_reason" => stop}
  end

  def from_openai(_response), do: %{"content" => [], "stop_reason" => "end_turn"}

  defp arguments(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, %{} = input} -> input
      _ -> %{}
    end
  end

  defp arguments(%{} = input), do: input
  defp arguments(_), do: %{}

  defp present(value) when value in [nil, ""], do: nil
  defp present(value), do: value
end
