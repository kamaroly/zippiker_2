defmodule Zippiker.Assistant.LLM do
  @moduledoc """
  Picks the AI a workspace uses and sends requests to it. A workspace's own
  provider (Settings → AI assistant, `AiSettings`) wins; otherwise the
  server's default, Anthropic with `ANTHROPIC_API_KEY`. Nil when neither
  has a key.
  """

  alias Zippiker.Assistant.{AiSettings, Claude, OpenAICompatible, Providers, Vault}

  @doc "The connection settings for a workspace, or nil."
  def resolve(organization) do
    workspace(organization) || server()
  end

  defp workspace(organization) do
    with {:ok, %AiSettings{enabled?: true} = settings} <-
           Ash.read_one(
             Ash.Query.for_read(AiSettings, :current, %{},
               tenant: organization,
               authorize?: false
             )
           ),
         {:ok, api_key} <- Vault.decrypt(settings.encrypted_api_key),
         %{} = provider <- Providers.get(settings.provider) do
      %{
        source: :workspace,
        provider: provider.key,
        label: provider.label,
        api: provider.api,
        base_url: present(settings.base_url) || provider.base_url,
        model: settings.model,
        api_key: api_key,
        effort: config()[:effort]
      }
    else
      _ -> nil
    end
  end

  defp server do
    if present(config()[:api_key]) do
      provider = Providers.get(:anthropic)

      %{
        source: :server,
        provider: :anthropic,
        label: provider.label,
        api: :anthropic,
        base_url: provider.base_url,
        model: config()[:model] || provider.model,
        api_key: config()[:api_key],
        effort: config()[:effort]
      }
    end
  end

  @doc "Sends one request in the Anthropic message format; replies come back in it too."
  def create(nil, _system, _tools, _messages), do: {:error, :not_configured}

  def create(%{api: :anthropic} = cfg, system, tools, messages),
    do: Claude.create(cfg, system, tools, messages)

  def create(cfg, system, tools, messages),
    do: OpenAICompatible.create(cfg, system, tools, messages)

  defp present(value) when value in [nil, ""], do: nil
  defp present(value), do: value

  defp config, do: Application.get_env(:zippiker, Zippiker.Assistant, [])
end
