defmodule Zippiker.Crm.Deal.Changes.SyncStage do
  @moduledoc """
  Copies pipeline and status from the stage, stamps `closed_at` when a deal is
  won or lost, and marks the deal's contact and company as customers on a win.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    stage_id = Ash.Changeset.get_attribute(changeset, :stage_id)

    if Ash.Changeset.changing_attribute?(changeset, :stage_id) and stage_id do
      case Ash.get(Zippiker.Crm.Stage, stage_id, tenant: changeset.tenant, authorize?: false) do
        {:ok, stage} -> apply_stage(changeset, stage, context)
        {:error, _} -> Ash.Changeset.add_error(changeset, field: :stage_id, message: "is invalid")
      end
    else
      changeset
    end
  end

  defp apply_stage(changeset, stage, context) do
    was = if changeset.action_type == :update, do: changeset.data.status, else: :open

    changeset
    |> Ash.Changeset.force_change_attribute(:pipeline_id, stage.pipeline_id)
    |> Ash.Changeset.force_change_attribute(:status, stage.kind)
    |> Ash.Changeset.force_change_attribute(:closed_at, closed_at(was, stage.kind, changeset))
    |> mark_customers(stage.kind == :won and was != :won, context)
  end

  defp closed_at(_was, :open, _changeset), do: nil
  defp closed_at(:open, _kind, _changeset), do: DateTime.utc_now()

  defp closed_at(_was, _kind, changeset),
    do: Ash.Changeset.get_attribute(changeset, :closed_at) || DateTime.utc_now()

  defp mark_customers(changeset, false, _context), do: changeset

  defp mark_customers(changeset, true, context) do
    Ash.Changeset.after_action(changeset, fn changeset, deal ->
      [deal.party_id, deal.company_id]
      |> Enum.reject(&is_nil/1)
      |> Enum.each(fn party_id ->
        Zippiker.Parties.Party
        |> Ash.get!(party_id, tenant: changeset.tenant, authorize?: false)
        |> Ash.Changeset.for_update(:add_role, %{role: :customer},
          tenant: changeset.tenant,
          actor: context.actor,
          authorize?: false
        )
        |> Ash.update!()
      end)

      {:ok, deal}
    end)
  end
end
