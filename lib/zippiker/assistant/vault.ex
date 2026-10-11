defmodule Zippiker.Assistant.Vault do
  @moduledoc """
  Encrypts workspace AI API keys at rest (AES-256-GCM via
  `Plug.Crypto.MessageEncryptor`). The key is derived from
  `:ai_keys_secret` (env `AI_KEYS_SECRET`), falling back to
  `:token_signing_secret`. Changing that secret makes stored keys
  unreadable: workspaces then re-enter them.
  """

  alias Plug.Crypto.{KeyGenerator, MessageEncryptor}

  def encrypt(plain) when is_binary(plain) do
    {secret, sign} = keys()
    MessageEncryptor.encrypt(plain, secret, sign)
  end

  def decrypt(nil), do: :error

  def decrypt(encrypted) when is_binary(encrypted) do
    {secret, sign} = keys()
    MessageEncryptor.decrypt(encrypted, secret, sign)
  end

  defp keys do
    base =
      Application.get_env(:zippiker, :ai_keys_secret) ||
        Application.fetch_env!(:zippiker, :token_signing_secret)

    {KeyGenerator.generate(base, "zippiker ai api keys", length: 32, cache: Plug.Crypto.Keys),
     KeyGenerator.generate(base, "zippiker ai api keys signing", cache: Plug.Crypto.Keys)}
  end
end
