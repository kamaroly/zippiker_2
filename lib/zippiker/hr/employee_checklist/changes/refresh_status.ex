defmodule Zippiker.HR.EmployeeChecklist.Changes.RefreshStatus do
  @moduledoc "Sets completed (with the time) when every task is done, in progress otherwise."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    checklist =
      Ash.load!(changeset.data, [:tasks],
        tenant: changeset.tenant,
        authorize?: false,
        reuse_values?: false
      )

    cond do
      checklist.status == :cancelled ->
        changeset

      checklist.tasks != [] and Enum.all?(checklist.tasks, &(&1.status == :done)) ->
        Ash.Changeset.force_change_attributes(changeset, %{
          status: :completed,
          completed_at: DateTime.utc_now()
        })

      true ->
        Ash.Changeset.force_change_attributes(changeset, %{
          status: :in_progress,
          completed_at: nil
        })
    end
  end
end
