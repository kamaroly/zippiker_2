defmodule Zippiker.Workflow.ApprovalWorkflow.Changes.NumberSteps do
  @moduledoc """
  Numbers steps in the order given (1, 2, …) and drops blank rows; a
  workflow needs at least one step.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :steps) do
      {:ok, steps} when is_list(steps) ->
        steps =
          steps
          |> Enum.reject(&(get(&1, :approver_type) in [nil, ""]))
          |> Enum.with_index(1)
          |> Enum.map(fn {step, position} ->
            step
            |> Map.new(fn {key, value} -> {to_string(key), value} end)
            |> Map.put("position", position)
          end)

        if steps == [] do
          Ash.Changeset.add_error(changeset, field: :steps, message: "add at least one approver")
        else
          Ash.Changeset.force_set_argument(changeset, :steps, steps)
        end

      _ ->
        changeset
    end
  end

  defp get(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
end
