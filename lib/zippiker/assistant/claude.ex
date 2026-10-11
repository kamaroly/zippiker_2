defmodule Zippiker.Assistant.Claude do
  @moduledoc """
  Calls the Claude Messages API (`POST /v1/messages`) over HTTP with Req
  (Elixir has no official Anthropic SDK).

  Configuration (`config/runtime.exs`, from the environment):

      config :zippiker, Zippiker.Assistant,
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: System.get_env("ANTHROPIC_MODEL", "claude-opus-5-5")

  Requests use adaptive thinking (the model's default), `medium` effort,
  automatic prompt caching, and server-side refusal fallbacks
  (`fallbacks: "default"`): if Claude's safety classifiers decline a turn,
  the API re-runs it on a fallback model inside the same call.
  """

  @url "https://api.anthropic.com/v1/messages"
  @fallback_beta "server-side-fallback-2026-07-01"

  def configured?, do: api_key() not in [nil, ""]

  def model, do: config()[:model] || "claude-opus-5-5"

  @doc """
  Sends one request. Returns `{:ok, response_map}` (string keys, as the API
  returns them) or `{:error, message}`.
  """
  def create(system, tools, messages) do
    if configured?() do
      body = %{
        model: model(),
        max_tokens: 16_000,
        system: system,
        tools: tools,
        messages: messages,
        output_config: %{effort: config()[:effort] || "medium"},
        cache_control: %{type: "ephemeral"},
        fallbacks: "default"
      }

      [
        url: @url,
        json: body,
        headers: [
          {"x-api-key", api_key()},
          {"anthropic-version", "2023-06-01"},
          {"anthropic-beta", @fallback_beta}
        ],
        receive_timeout: 300_000,
        retry: :transient,
        max_retries: 2
      ]
      |> Keyword.merge(config()[:req_options] || [])
      |> Req.post()
      |> case do
        {:ok, %Req.Response{status: 200, body: response}} ->
          {:ok, response}

        {:ok, %Req.Response{status: 401}} ->
          {:error, "The Anthropic API key was rejected. Check ANTHROPIC_API_KEY."}

        {:ok, %Req.Response{status: 429}} ->
          {:error, "The AI service is busy (rate limited). Try again in a moment."}

        {:ok, %Req.Response{status: status, body: %{"error" => %{"message" => message}}}} ->
          {:error, "The AI service returned an error (#{status}): #{message}"}

        {:ok, %Req.Response{status: status}} ->
          {:error, "The AI service returned an error (#{status})."}

        {:error, exception} ->
          {:error, "Couldn't reach the AI service: #{Exception.message(exception)}"}
      end
    else
      {:error, :not_configured}
    end
  end

  defp api_key, do: config()[:api_key]
  defp config, do: Application.get_env(:zippiker, Zippiker.Assistant, [])
end
