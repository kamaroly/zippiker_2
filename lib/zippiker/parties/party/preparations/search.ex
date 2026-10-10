defmodule Zippiker.Parties.Party.Preparations.Search do
  @moduledoc "Optional free-text and role filters for the party directory."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> filter_query(Ash.Query.get_argument(query, :query))
    |> filter_role(Ash.Query.get_argument(query, :role))
    |> filter_employer(Ash.Query.get_argument(query, :employer_id))
  end

  defp filter_query(query, term) when is_binary(term) and term != "" do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(name, ^pattern) or ilike(email, ^pattern) or ilike(phone, ^pattern)
    )
  end

  defp filter_query(query, _term), do: query

  defp filter_role(query, role) when is_atom(role) and not is_nil(role),
    do: Ash.Query.filter(query, ^role in roles)

  defp filter_role(query, _role), do: query

  defp filter_employer(query, nil), do: query
  defp filter_employer(query, id), do: Ash.Query.filter(query, employer_id == ^id)
end
