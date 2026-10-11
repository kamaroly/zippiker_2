defmodule Zippiker.HR.Checks.AssigneeOfTask do
  @moduledoc "Passes when the actor is the assignee of the attachment's checklist task."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "the actor is the task's assignee"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: %Ash.Changeset{} = changeset}, _opts) do
    task_id =
      Ash.Changeset.get_attribute(changeset, :task_id) || Map.get(changeset.data, :task_id)

    case task_id &&
           Ash.get(Zippiker.HR.ChecklistTask, task_id,
             tenant: changeset.tenant,
             authorize?: false
           ) do
      {:ok, %{assignee_id: assignee}} -> assignee == actor.id
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
