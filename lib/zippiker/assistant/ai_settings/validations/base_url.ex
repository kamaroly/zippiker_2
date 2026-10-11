defmodule Zippiker.Assistant.AiSettings.Validations.BaseUrl do
  @moduledoc """
  "Other" providers need a base URL: https, or http on localhost (a local
  model server).
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    provider = Ash.Changeset.get_attribute(changeset, :provider)
    url = Ash.Changeset.get_attribute(changeset, :base_url)

    cond do
      provider != :custom -> :ok
      url in [nil, ""] -> {:error, field: :base_url, message: "is required for other providers"}
      ok_url?(URI.parse(url)) -> :ok
      true -> {:error, field: :base_url, message: "must be an https:// URL (or http://localhost)"}
    end
  end

  defp ok_url?(%URI{scheme: "https", host: host}) when is_binary(host) and host != "", do: true
  defp ok_url?(%URI{scheme: "http", host: host}) when host in ["localhost", "127.0.0.1"], do: true
  defp ok_url?(_uri), do: false
end
