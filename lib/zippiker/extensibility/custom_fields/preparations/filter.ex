defmodule Zippiker.Extensibility.CustomFields.Preparations.Filter do
  @moduledoc """
  Filters a read by custom field values given in a `custom_fields` map
  argument, e.g. `%{"tier" => "Gold"}`. Text, select and yes/no compare the
  stored text; multi-select matches when the value is one of the selections.
  Unknown keys and blank values are ignored.

      argument :custom_fields, :map
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @key ~r/^[a-z][a-z0-9_]*$/

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :custom_fields) do
      filters when is_map(filters) and map_size(filters) > 0 -> apply_filters(query, filters)
      _ -> query
    end
  end

  defp apply_filters(query, filters) do
    entity_types = definition_types(query)

    Enum.reduce(filters, query, fn {key, value}, query ->
      key = to_string(key)

      cond do
        value in [nil, ""] or not Regex.match?(@key, key) ->
          query

        Map.get(entity_types, key) == :multi_select ->
          Ash.Query.filter(
            query,
            fragment("jsonb_exists(? -> ?, ?)", custom_fields, ^key, ^to_string(value))
          )

        Map.has_key?(entity_types, key) ->
          Ash.Query.filter(
            query,
            fragment("(? ->> ?) = ?", custom_fields, ^key, ^to_string(value))
          )

        true ->
          query
      end
    end)
  end

  # Entity of the resource (fixed or the `entity_from` attribute's filtered value).
  defp definition_types(query) do
    entity =
      case Zippiker.Extensibility.CustomFields.Info.custom_fields_entity(query.resource) do
        {:ok, entity} -> entity
        :error -> Ash.Query.get_argument(query, :kind)
      end

    entity
    |> Zippiker.Extensibility.list_custom_fields!(tenant: query.tenant, authorize?: false)
    |> Map.new(&{&1.key, &1.type})
  end
end
