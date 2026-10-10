defmodule Zippiker.Accounting.JournalEntry.Preparations.Search do
  @moduledoc "Filters by number/memo/source document text and by source."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> by_text(Ash.Query.get_argument(query, :query))
    |> by_source(Ash.Query.get_argument(query, :source))
  end

  defp by_text(query, text) when is_binary(text) and text != "" do
    pattern = "%" <> String.replace(String.trim(text), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(number, ^pattern) or ilike(memo, ^pattern) or ilike(source_label, ^pattern)
    )
  end

  defp by_text(query, _text), do: query

  defp by_source(query, nil), do: query
  defp by_source(query, source), do: Ash.Query.filter(query, source == ^source)
end
