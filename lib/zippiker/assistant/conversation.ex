defmodule Zippiker.Assistant.Conversation do
  @moduledoc "A chat with the assistant, driven through generic actions (no storage)."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Assistant,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Assistant.Conversation.Actions,
      Zippiker.Assistant.Conversation.Policies
    ]
end
