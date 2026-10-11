defmodule Zippiker.Assistant.AiSettings.Actions.Configure do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Assistant.AiSettings

  @impl true
  def run(input, _opts, context) do
    opts = [actor: context.actor, tenant: input.tenant]
    params = Map.take(input.arguments, [:provider, :model, :base_url, :enabled?, :api_key])

    case Ash.read_one(Ash.Query.for_read(AiSettings, :current, %{}, opts)) do
      {:ok, nil} ->
        AiSettings |> Ash.Changeset.for_create(:create, params, opts) |> Ash.create()

      {:ok, settings} ->
        settings |> Ash.Changeset.for_update(:update, params, opts) |> Ash.update()

      {:error, error} ->
        {:error, error}
    end
  end
end
