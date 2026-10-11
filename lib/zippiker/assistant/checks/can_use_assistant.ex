defmodule Zippiker.Assistant.Checks.CanUseAssistant do
  @moduledoc "Owners, admins and members whose roles include \"Use the AI assistant\"."
  use Ash.Policy.SimpleCheck

  alias Zippiker.Accounts.Checks.Membership

  @impl true
  def describe(_opts), do: "actor may use the AI assistant"

  @impl true
  def match?(actor, context, _opts) do
    case Membership.permissions(actor, context) do
      :all -> true
      %MapSet{} = granted -> MapSet.member?(granted, "assistant.use")
      _ -> false
    end
  end
end
