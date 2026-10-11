defmodule Zippiker.HR.TimeActivity.Preparations.Search do
  @moduledoc "Filters time by employee, the actor's own, and a date range."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    actor_id = context.actor && context.actor.id
    arg = &Ash.Query.get_argument(query, &1)

    query
    |> then(
      &if(arg.(:employee_id),
        do: Ash.Query.filter(&1, employee_id == ^arg.(:employee_id)),
        else: &1
      )
    )
    |> then(&if(arg.(:mine?), do: Ash.Query.filter(&1, employee.user_id == ^actor_id), else: &1))
    |> then(&if(arg.(:from), do: Ash.Query.filter(&1, date >= ^arg.(:from)), else: &1))
    |> then(&if(arg.(:to), do: Ash.Query.filter(&1, date <= ^arg.(:to)), else: &1))
  end
end
