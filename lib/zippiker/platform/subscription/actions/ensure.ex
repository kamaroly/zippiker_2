defmodule Zippiker.Platform.Subscription.Actions.Ensure do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Platform.{Plan, Subscription}

  @impl true
  def run(input, _opts, _context) do
    organization_id = input.arguments.organization_id

    Subscription
    |> Ash.Query.filter(organization_id == ^organization_id)
    |> Ash.Query.load(:plan)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> start(organization_id)
      other -> other
    end
  end

  defp start(organization_id) do
    with {:ok, plan} <- default_plan() do
      Subscription
      |> Ash.Changeset.for_create(:start, %{organization_id: organization_id, plan_id: plan.id})
      |> Ash.create(authorize?: false, load: [:plan])
    end
  end

  # The plan flagged default, else the first active one; created if the
  # platform has no plans yet (fresh install).
  defp default_plan do
    Plan
    |> Ash.Query.filter(active? == true)
    |> Ash.Query.sort(default?: :desc, position: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} ->
        Plan
        |> Ash.Changeset.for_create(:create, %{
          code: "standard",
          name: "Standard",
          price_per_seat: Decimal.new(10),
          default?: true
        })
        |> Ash.create(authorize?: false)

      other ->
        other
    end
  end
end
