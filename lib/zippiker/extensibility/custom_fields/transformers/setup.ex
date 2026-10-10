defmodule Zippiker.Extensibility.CustomFields.Transformers.Setup do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @impl true
  def before?(Ash.Resource.Transformers.DefaultAccept), do: true
  def before?(Ash.Resource.Transformers.SetTypes), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    entity = Transformer.get_option(dsl_state, [:custom_fields], :entity)
    entity_from = Transformer.get_option(dsl_state, [:custom_fields], :entity_from)

    cond do
      is_nil(entity) and is_nil(entity_from) ->
        {:error,
         Spark.Error.DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:custom_fields],
           message: "set either `entity` or `entity_from`"
         )}

      entity && entity not in Zippiker.Extensibility.Entity.values() ->
        {:error,
         Spark.Error.DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:custom_fields, :entity],
           message: "#{inspect(entity)} is not a Zippiker.Extensibility.Entity value"
         )}

      true ->
        dsl_state
        |> Ash.Resource.Builder.add_new_attribute(:custom_fields, :map,
          allow_nil?: false,
          default: %{},
          public?: true
        )
        |> Ash.Resource.Builder.add_change(
          Zippiker.Extensibility.CustomFields.Changes.CastValues,
          on: [:create, :update]
        )
    end
  end
end
