defmodule Zippiker.Assistant.Conversation.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Assistant.Conversation.Actions

  actions do
    action :reply, :map do
      description "Sends the user's message and runs the assistant's turn."
      argument :history, {:array, :map}, allow_nil?: false, default: []
      argument :text, :string, allow_nil?: false, constraints: [max_length: 8_000]
      run {Actions.Turn, step: :reply}
    end

    action :resolve, :map do
      description "Approves or declines the write actions the assistant proposed, then continues."
      argument :history, {:array, :map}, allow_nil?: false
      argument :pending, :map, allow_nil?: false
      argument :approved?, :boolean, allow_nil?: false
      run {Actions.Turn, step: :resolve}
    end

    action :status, :map do
      description "Whether the assistant is set up (an API key is configured) and which model it uses."
      run Actions.Status
    end
  end
end
