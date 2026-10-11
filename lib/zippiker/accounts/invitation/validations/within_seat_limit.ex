defmodule Zippiker.Accounts.Invitation.Validations.WithinSeatLimit do
  @moduledoc """
  Members plus open invitations may not exceed the workspace's `seat_limit`
  (set by its billing plan; nil means unlimited).
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias Zippiker.Accounts.{Invitation, Membership, Organization}

  @impl true
  def validate(changeset, _opts, _context) do
    organization_id = Zippiker.Accounts.Tenant.organization_id(changeset.tenant)

    case Ash.get(Organization, organization_id, authorize?: false) do
      {:ok, %{seat_limit: limit}} when is_integer(limit) ->
        if seats_taken(organization_id) >= limit do
          {:error,
           field: :email,
           message:
             "your plan includes #{limit} seats and they're all taken; upgrade under Settings → Billing"}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  defp seats_taken(organization_id) do
    members =
      Membership
      |> Ash.Query.filter(organization_id == ^organization_id)
      |> Ash.count!(authorize?: false)

    pending =
      Invitation
      |> Ash.Query.filter(
        organization_id == ^organization_id and is_nil(accepted_at) and expires_at > now()
      )
      |> Ash.count!(authorize?: false)

    members + pending
  end
end
