defmodule Zippiker.Workflow.ApprovalStep.Validations.ApproverChosen do
  @moduledoc "A user step needs a user, a group step needs a group."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :approver_type) do
      :user ->
        if Ash.Changeset.get_attribute(changeset, :user_id),
          do: :ok,
          else: {:error, field: :user_id, message: "choose the approver"}

      :group ->
        if Ash.Changeset.get_attribute(changeset, :group_id),
          do: :ok,
          else: {:error, field: :group_id, message: "choose the group"}

      _ ->
        :ok
    end
  end
end
