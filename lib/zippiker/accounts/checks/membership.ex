defmodule Zippiker.Accounts.Checks.Membership do
  @moduledoc """
  Resolves the actor's role in the tenant of a policy context. Uses the
  actor's preloaded memberships when available to avoid a query per check.

  Super admins who don't belong to the workspace act as `:admin` there, which
  is how the platform panel's "Open workspace" works.
  """
  require Ash.Query

  def role(nil, _context), do: nil

  def role(actor, context) do
    with organization_id when is_binary(organization_id) <- tenant(context) do
      role =
        actor
        |> memberships(organization_id)
        |> Enum.find_value(&(&1.organization_id == organization_id && &1.role))

      role || platform_role(actor)
    else
      _ -> nil
    end
  end

  defp platform_role(%{super_admin?: true}), do: :admin
  defp platform_role(_actor), do: nil

  defp tenant(%{subject: %{tenant: tenant}}) when not is_nil(tenant),
    do: Ash.ToTenant.to_tenant(tenant, nil)

  defp tenant(%{changeset: %{tenant: tenant}}) when not is_nil(tenant),
    do: Ash.ToTenant.to_tenant(tenant, nil)

  defp tenant(%{query: %{tenant: tenant}}) when not is_nil(tenant),
    do: Ash.ToTenant.to_tenant(tenant, nil)

  defp tenant(_context), do: nil

  defp memberships(%{memberships: memberships}, _organization_id) when is_list(memberships),
    do: memberships

  defp memberships(actor, organization_id) do
    Zippiker.Accounts.Membership
    |> Ash.Query.filter(user_id == ^actor.id and organization_id == ^organization_id)
    |> Ash.read!(authorize?: false)
  end
end
