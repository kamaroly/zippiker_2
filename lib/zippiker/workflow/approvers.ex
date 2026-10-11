defmodule Zippiker.Workflow.Approvers do
  @moduledoc """
  Resolves who may decide a request step: the initiator's manager (from HR),
  the manager or else the admins, a specific user, the members of a group,
  or the workspace admins. The
  initiator never approves their own request.
  """

  require Ash.Query

  @doc "User ids that may decide `step` of `request` (requested_by_id excluded)."
  def for_step(step, request, tenant) do
    opts = [tenant: tenant, authorize?: false]

    ids =
      case step.approver_type do
        :user -> [step.user_id]
        :group -> group_members(step.group_id, opts)
        :manager -> manager(request.requested_by_id, opts)
        :manager_or_admins -> manager_or_admins(request, tenant, opts)
        :admins -> admins(tenant)
      end

    ids |> Enum.reject(&(is_nil(&1) or &1 == request.requested_by_id)) |> Enum.uniq()
  end

  defp group_members(nil, _opts), do: []

  defp group_members(group_id, opts) do
    Zippiker.Workflow.ApprovalGroupMember
    |> Ash.Query.filter(group_id == ^group_id)
    |> Ash.read!(opts)
    |> Enum.map(& &1.user_id)
  end

  # The initiator's manager; any admin when they have none (or it's themselves).
  defp manager_or_admins(request, tenant, opts) do
    case manager(request.requested_by_id, opts) -- [request.requested_by_id] do
      [] -> admins(tenant)
      managers -> managers
    end
  end

  defp manager(nil, _opts), do: []

  defp manager(user_id, opts) do
    Zippiker.HR.Employee
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.load(:manager)
    |> Ash.read_one!(opts)
    |> case do
      %{manager: %{user_id: manager_user}} when is_binary(manager_user) -> [manager_user]
      _ -> []
    end
  end

  defp admins(tenant) do
    organization_id = Zippiker.Accounts.Tenant.organization_id(tenant)

    Zippiker.Accounts.Membership
    |> Ash.Query.filter(organization_id == ^organization_id and role in [:owner, :admin])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
  end
end
