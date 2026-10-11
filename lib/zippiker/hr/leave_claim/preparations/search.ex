defmodule Zippiker.HR.LeaveClaim.Preparations.Search do
  @moduledoc "Filters claims by status, the actor's own, or those waiting on the actor (as manager)."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    actor_id = context.actor && context.actor.id
    arg = &Ash.Query.get_argument(query, &1)

    query
    |> then(&if(arg.(:status), do: Ash.Query.filter(&1, status == ^arg.(:status)), else: &1))
    |> then(&if(arg.(:mine?), do: Ash.Query.filter(&1, employee.user_id == ^actor_id), else: &1))
    |> then(
      &if(arg.(:to_decide?),
        do: Ash.Query.filter(&1, status == :pending and employee.manager.user_id == ^actor_id),
        else: &1
      )
    )
  end
end
