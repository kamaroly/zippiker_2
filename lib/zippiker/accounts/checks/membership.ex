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

  @doc """
  What the actor may do in the context's workspace: `:all` (owners, admins,
  super admins), a `MapSet` of permission keys (members, from their roles)
  or nil (not a member).
  """
  def permissions(nil, _context), do: nil

  def permissions(actor, context) do
    with organization_id when is_binary(organization_id) <- tenant(context) do
      permissions_in(actor, organization_id)
    else
      _ -> nil
    end
  end

  @doc "Like `permissions/2`, for a workspace id."
  def permissions_in(actor, organization_id) do
    case actor
         |> memberships(organization_id)
         |> Enum.find(&(&1.organization_id == organization_id)) do
      %{role: role} when role in [:owner, :admin] ->
        :all

      %{} = membership ->
        membership
        |> roles()
        |> Enum.flat_map(& &1.permissions)
        |> MapSet.new()

      nil ->
        if platform_role(actor), do: :all
    end
  end

  defp roles(%{roles: roles}) when is_list(roles), do: roles

  defp roles(membership) do
    Ash.load!(membership, :roles, authorize?: false).roles
  end

  defp platform_role(%{super_admin?: true}), do: :admin
  defp platform_role(_actor), do: nil

  defp tenant(%{subject: %{tenant: tenant}}) when not is_nil(tenant),
    do: Zippiker.Accounts.Tenant.organization_id(tenant)

  defp tenant(%{changeset: %{tenant: tenant}}) when not is_nil(tenant),
    do: Zippiker.Accounts.Tenant.organization_id(tenant)

  defp tenant(%{query: %{tenant: tenant}}) when not is_nil(tenant),
    do: Zippiker.Accounts.Tenant.organization_id(tenant)

  defp tenant(_context), do: nil

  defp memberships(%{memberships: memberships}, _organization_id) when is_list(memberships),
    do: memberships

  defp memberships(actor, organization_id) do
    Zippiker.Accounts.Membership
    |> Ash.Query.filter(user_id == ^actor.id and organization_id == ^organization_id)
    |> Ash.read!(authorize?: false)
  end
end
