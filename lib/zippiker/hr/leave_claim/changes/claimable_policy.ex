defmodule Zippiker.HR.LeaveClaim.Changes.ClaimablePolicy do
  @moduledoc "Links the claim to the employee's policy for the leave type, which must allow claims."
  use Ash.Resource.Change

  alias Zippiker.HR.Entitlement

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      employee_id = Ash.Changeset.get_attribute(changeset, :employee_id)
      type_id = Ash.Changeset.get_attribute(changeset, :leave_type_id)
      opts = [tenant: changeset.tenant, authorize?: false]

      case employee_id && type_id && Entitlement.policy_for(employee_id, type_id, opts) do
        %{claimable?: true, id: id} ->
          Ash.Changeset.force_change_attribute(changeset, :leave_policy_id, id)

        _ ->
          Ash.Changeset.add_error(changeset,
            field: :leave_type_id,
            message: "this leave can't be claimed under your leave policy"
          )
      end
    end)
  end
end
