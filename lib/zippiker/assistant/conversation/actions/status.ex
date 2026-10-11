defmodule Zippiker.Assistant.Conversation.Actions.Status do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    organization = Zippiker.Reporting.Context.organization(input.tenant)

    case Zippiker.Assistant.LLM.resolve(organization) do
      nil ->
        {:ok, %{configured?: false, model: nil, provider: nil, source: nil}}

      cfg ->
        {:ok, %{configured?: true, model: cfg.model, provider: cfg.label, source: cfg.source}}
    end
  end
end
