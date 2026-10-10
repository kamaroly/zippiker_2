defmodule Zippiker.Accounts.Organization.Preparations.PlatformSearch do
  @moduledoc "Case-insensitive match on the workspace name."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :query) do
      text when is_binary(text) and text != "" ->
        pattern = "%" <> String.replace(String.trim(text), ~r/[%_\\]/, "\\\\\\0") <> "%"
        Ash.Query.filter(query, ilike(name, ^pattern))

      _ ->
        query
    end
  end
end
