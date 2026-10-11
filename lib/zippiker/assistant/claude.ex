defmodule Zippiker.Assistant.Claude do
  @moduledoc """
  Anthropic adapter: calls the Claude Messages API (`POST /v1/messages`)
  over HTTP with Req (Elixir has no official Anthropic SDK). The
  conversation format used across the assistant is this API's format.

  Requests use adaptive thinking (the model's default), the configured
  effort, automatic prompt caching and, on the models that support it,
  server-side refusal fallbacks (`fallbacks: "default"`): if Claude's
  safety classifiers decline a turn, the API re-runs it on a fallback model
  inside the same call.
  """

  alias Zippiker.Assistant.HTTP

  @fallback_beta "server-side-fallback-2026-07-01"
  @fallback_models ~w(claude-opus-5-5 claude-opus-5 claude-fable-5-1 claude-sonnet-5-5)

  def create(cfg, system, tools, messages) do
    model = cfg.model

    body =
      %{
        model: model,
        max_tokens: 16_000,
        system: system,
        tools: tools,
        messages: messages,
        cache_control: %{type: "ephemeral"}
      }
      |> maybe(effort?(model), :output_config, %{effort: cfg[:effort] || "medium"})
      |> maybe(model in @fallback_models, :fallbacks, "default")

    headers =
      [{"x-api-key", cfg.api_key}, {"anthropic-version", "2023-06-01"}] ++
        if model in @fallback_models, do: [{"anthropic-beta", @fallback_beta}], else: []

    HTTP.post(String.trim_trailing(cfg.base_url, "/") <> "/messages", body, headers, "Anthropic")
  end

  # Effort isn't accepted by older models (Haiku 4.5, Sonnet 4.5 and earlier).
  defp effort?(model),
    do: not String.starts_with?(model, ["claude-haiku-4", "claude-sonnet-4-5", "claude-3"])

  defp maybe(map, true, key, value), do: Map.put(map, key, value)
  defp maybe(map, _false, _key, _value), do: map
end
