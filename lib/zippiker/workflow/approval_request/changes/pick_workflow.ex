defmodule Zippiker.Workflow.ApprovalRequest.Changes.PickWorkflow do
  @moduledoc """
  Copies the steps of the active workflow for the document type with the
  highest `min_amount` not above the document's amount. Without a workflow,
  the document type's default steps apply (`Workflow.DocumentTypes`).
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    type = Ash.Changeset.get_attribute(changeset, :document_type)
    amount = Ash.Changeset.get_attribute(changeset, :amount) || Decimal.new(0)

    workflow =
      Zippiker.Workflow.ApprovalWorkflow
      |> Ash.Query.filter(document_type == ^type and active? == true and min_amount <= ^amount)
      |> Ash.Query.sort(min_amount: :desc)
      |> Ash.Query.limit(1)
      |> Ash.Query.load(:steps)
      |> Ash.read_one!(tenant: changeset.tenant, authorize?: false)

    steps =
      case workflow do
        nil ->
          Zippiker.Workflow.DocumentTypes.default_steps(type)

        workflow ->
          Enum.map(workflow.steps, fn step ->
            Map.take(step, [:position, :label, :approver_type, :user_id, :group_id])
          end)
      end

    changeset
    |> Ash.Changeset.force_change_attribute(:workflow_id, workflow && workflow.id)
    |> Ash.Changeset.force_set_argument(:steps, steps)
  end
end
