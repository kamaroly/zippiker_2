defmodule ZippikerWeb.Settings.AiLive do
  @moduledoc """
  Bring your own AI: the workspace picks Claude, ChatGPT, Grok, Gemini or
  another OpenAI-compatible provider, a model and its API key. Keys are
  encrypted and only their last four characters are shown.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Assistant
  alias Zippiker.Assistant.{LLM, Providers}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "AI assistant", test: nil) |> load()}
  end

  defp load(socket) do
    settings =
      case Assistant.ai_settings(ash_opts(socket)) do
        {:ok, settings} -> settings
        _ -> nil
      end

    provider = (settings && settings.provider) || :anthropic

    params = %{
      "provider" => to_string(provider),
      "model" => (settings && settings.model) || Providers.get(provider).model,
      "base_url" => settings && settings.base_url,
      "enabled?" => if(settings, do: to_string(settings.enabled?), else: "true"),
      "api_key" => ""
    }

    assign(socket,
      settings: settings,
      form: to_form(params, as: "ai"),
      errors: [],
      server_default?: server_default?()
    )
  end

  defp server_default? do
    config = Application.get_env(:zippiker, Zippiker.Assistant, [])
    config[:api_key] not in [nil, ""]
  end

  @impl true
  def handle_event("change", %{"ai" => params, "_target" => target}, socket) do
    # Picking another provider fills in its suggested model.
    params =
      if target == ["ai", "provider"] do
        provider = Enum.find(Providers.all(), &(to_string(&1.key) == params["provider"]))
        Map.put(params, "model", (provider && provider.model) || "")
      else
        params
      end

    {:noreply, assign(socket, form: to_form(params, as: "ai"), test: nil)}
  end

  def handle_event("save", %{"ai" => params}, socket) do
    case Assistant.configure_ai(
           %{
             provider: provider_key(params["provider"]),
             model: String.trim(params["model"] || ""),
             base_url: blank(params["base_url"]),
             enabled?: params["enabled?"] != "false",
             api_key: blank(params["api_key"])
           },
           ash_opts(socket)
         ) do
      {:ok, _settings} ->
        {:noreply, socket |> put_flash(:info, "AI provider saved") |> load()}

      {:error, error} ->
        {:noreply, assign(socket, errors: [error_message(error)])}
    end
  end

  def handle_event("remove_key", _params, socket) do
    case Assistant.remove_ai_key(socket.assigns.settings, ash_opts(socket)) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "API key removed") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  # Sends a one-line request with the saved settings.
  def handle_event("test", _params, socket) do
    organization = socket.assigns.current_organization

    result =
      case LLM.resolve(organization) do
        nil ->
          {:error, "No provider with a key is set up yet."}

        cfg ->
          case LLM.create(cfg, "Reply with the single word OK.", [], [
                 %{"role" => "user", "content" => "Connection test"}
               ]) do
            {:ok, _response} -> {:ok, "#{cfg.label} answered using #{cfg.model}."}
            {:error, message} -> {:error, message}
          end
      end

    {:noreply, assign(socket, :test, result)}
  end

  defp provider_key(value) do
    Enum.find(Providers.keys(), :anthropic, &(to_string(&1) == value))
  end

  defp blank(value) when value in [nil, ""], do: nil
  defp blank(value), do: String.trim(value)

  defp current_provider(form),
    do: Providers.get(provider_key(form[:provider].value)) || Providers.get(:anthropic)
end
