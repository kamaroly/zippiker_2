defmodule Zippiker.Assistant.Conversation.Actions.Status do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Assistant.Claude

  @impl true
  def run(_input, _opts, _context),
    do: {:ok, %{configured?: Claude.configured?(), model: Claude.model()}}
end
