defmodule Zippiker.Portal.Access do
  @moduledoc """
  Checks the actor may use a portal access (theirs, active, of the right
  kind) and returns it with the team to use as tenant. Portal actions read
  with authorization off, so they must go through here and filter on
  `access.party_id`.
  """

  def verify(actor, access_id, kind \\ nil)

  def verify(nil, _access_id, _kind), do: {:error, "sign in to use the portal"}

  def verify(actor, access_id, kind) do
    case Ash.get(Zippiker.Accounts.PortalAccess, access_id,
           authorize?: false,
           load: [:organization]
         ) do
      {:ok, %{user_id: user_id, status: :active} = access}
      when user_id == actor.id and (is_nil(kind) or access.kind == kind) ->
        {:ok, access, access.organization}

      _ ->
        {:error, "you don't have access to this portal"}
    end
  end

  def opts(organization), do: [tenant: organization, authorize?: false]
end
