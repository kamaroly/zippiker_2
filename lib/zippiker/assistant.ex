defmodule Zippiker.Assistant do
  @moduledoc """
  The AI assistant: a conversation with Claude that can search, report and
  prepare records as the signed-in user. See `Zippiker.Assistant.Engine`
  and docs/ai-assistant.md.
  """
  use Ash.Domain, otp_app: :zippiker

  resources do
    resource Zippiker.Assistant.AiSettings do
      define :ai_settings, action: :current
      define :configure_ai, action: :configure
      define :remove_ai_key, action: :remove_key
    end

    resource Zippiker.Assistant.Conversation do
      define :assistant_reply, action: :reply, args: [:history, :text]
      define :assistant_resolve, action: :resolve, args: [:history, :pending, :approved?]
      define :assistant_status, action: :status
    end
  end
end
