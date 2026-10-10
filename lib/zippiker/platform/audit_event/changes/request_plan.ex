defmodule Zippiker.Platform.AuditEvent.Changes.RequestPlan do
  @moduledoc "Records the request against the tenant workspace (never a client-supplied one)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    plan_id = Ash.Changeset.get_argument(changeset, :plan_id)

    case {changeset.tenant, Ash.get(Zippiker.Platform.Plan, plan_id, authorize?: false)} do
      {tenant, {:ok, plan}} when not is_nil(tenant) ->
        Ash.Changeset.force_change_attributes(changeset, %{
          action: :plan_requested,
          organization_id: Ash.ToTenant.to_tenant(tenant, nil),
          summary: "Requested the #{plan.name} plan"
        })

      _ ->
        Ash.Changeset.add_error(changeset, field: :plan_id, message: "unknown plan")
    end
  end
end
