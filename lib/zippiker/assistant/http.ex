defmodule Zippiker.Assistant.HTTP do
  @moduledoc "JSON POSTs to AI providers with Req, and friendly error messages."

  def post(url, body, headers, provider) do
    [
      url: url,
      json: body,
      headers: headers,
      receive_timeout: 300_000,
      retry: :transient,
      max_retries: 2
    ]
    |> Keyword.merge(Application.get_env(:zippiker, Zippiker.Assistant, [])[:req_options] || [])
    |> Req.post()
    |> case do
      {:ok, %Req.Response{status: 200, body: %{} = response}} ->
        {:ok, response}

      {:ok, %Req.Response{status: status}} when status in [401, 403] ->
        {:error, "The #{provider} API key was rejected. Check it in Settings → AI assistant."}

      {:ok, %Req.Response{status: 429}} ->
        {:error,
         "#{provider} is busy or the account is out of credit (rate limited). Try again shortly."}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "#{provider} returned an error (#{status})#{detail(body)}"}

      {:error, exception} ->
        {:error, "Couldn't reach #{provider}: #{Exception.message(exception)}"}
    end
  end

  defp detail(%{"error" => %{"message" => message}}), do: ": " <> message
  defp detail([%{"error" => %{"message" => message}} | _]), do: ": " <> message
  defp detail(_body), do: "."
end
