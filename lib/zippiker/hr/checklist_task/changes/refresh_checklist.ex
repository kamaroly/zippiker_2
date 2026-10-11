defmodule Zippiker.HR.ChecklistTask.Changes.RefreshChecklist do
  @moduledoc "After a task changes, the checklist completes (or reopens) accordingly."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, task ->
      opts = [tenant: changeset.tenant, authorize?: false]

      Zippiker.HR.EmployeeChecklist
      |> Ash.get!(task.checklist_id, opts)
      |> Ash.Changeset.for_update(:refresh_status, %{}, opts)
      |> Ash.update!(authorize?: false)

      {:ok, task}
    end)
  end
end
