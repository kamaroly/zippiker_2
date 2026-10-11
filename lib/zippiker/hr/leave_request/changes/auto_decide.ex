defmodule Zippiker.HR.LeaveRequest.Changes.AutoDecide do
  @moduledoc "Approves or rejects an overdue request on the policy's behalf, with a note saying so."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    decision = Ash.Changeset.get_argument(changeset, :decision)

    Ash.Changeset.force_change_attributes(changeset, %{
      status: if(decision == :approve, do: :approved, else: :rejected),
      decided_at: DateTime.utc_now(),
      auto_decided?: true,
      decision_note:
        "Automatically #{if decision == :approve, do: "approved", else: "rejected"}: not reviewed in time"
    })
  end
end
