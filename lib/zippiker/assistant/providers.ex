defmodule Zippiker.Assistant.Providers do
  @moduledoc """
  The AI providers a workspace can bring. Anthropic is called through its
  Messages API; the others through the OpenAI-compatible Chat Completions
  API (OpenAI, xAI Grok, Google Gemini's compatibility endpoint, or any
  compatible base URL such as OpenRouter or a local Ollama).

  Suggested models are only defaults for the form; any model name the
  provider accepts works.
  """

  @providers [
    %{
      key: :anthropic,
      label: "Anthropic Claude",
      api: :anthropic,
      base_url: "https://api.anthropic.com/v1",
      model: "claude-opus-5-5",
      keys_url: "https://platform.claude.com/settings/keys",
      hint: "Keys start with sk-ant-."
    },
    %{
      key: :openai,
      label: "OpenAI (ChatGPT)",
      api: :openai,
      base_url: "https://api.openai.com/v1",
      model: "gpt-5",
      keys_url: "https://platform.openai.com/api-keys",
      hint: "Keys start with sk-."
    },
    %{
      key: :xai,
      label: "xAI Grok",
      api: :openai,
      base_url: "https://api.x.ai/v1",
      model: "grok-4",
      keys_url: "https://console.x.ai",
      hint: "Keys start with xai-."
    },
    %{
      key: :gemini,
      label: "Google Gemini",
      api: :openai,
      base_url: "https://generativelanguage.googleapis.com/v1beta/openai",
      model: "gemini-2.5-pro",
      keys_url: "https://aistudio.google.com/apikey",
      hint: "Create the key in Google AI Studio."
    },
    %{
      key: :custom,
      label: "Other (OpenAI-compatible)",
      api: :openai,
      base_url: nil,
      model: nil,
      keys_url: nil,
      hint: "Any OpenAI-compatible endpoint, e.g. OpenRouter (https://openrouter.ai/api/v1)."
    }
  ]

  def all, do: @providers
  def keys, do: Enum.map(@providers, & &1.key)
  def get(key), do: Enum.find(@providers, &(&1.key == key))
  def label(key), do: (get(key) || %{label: to_string(key)}).label
end
