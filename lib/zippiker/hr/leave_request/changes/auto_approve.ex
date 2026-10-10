defmodule Zippiker.HR.LeaveRequest.Changes.AutoApprove do
  @moduledoc "Leave types that don't need approval are approved on request."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    with id when is_binary(id) <- Ash.Changeset.get_attribute(changeset, :leave_type_id),
         {:ok, %{requires_approval?: false}} <-
           Zippiker.HR.get_leave_type(id, tenant: changeset.tenant, authorize?: false) do
      Ash.Changeset.force_change_attributes(changeset, %{
        status: :approved,
        decided_at: DateTime.utc_now()
      })
    else
      _ -> changeset
    end
  end
end
