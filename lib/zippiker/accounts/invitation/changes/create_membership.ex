defmodule Zippiker.Accounts.Invitation.Changes.CreateMembership do
  @moduledoc "Adds the accepting user to the workspace (or keeps an existing membership)."
  use Ash.Resource.Change

  require Ash.Query

  # A workspace opened from the platform has no owner until its invitation is
  # accepted: the first person to accept becomes the owner.
  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      owned? =
        Zippiker.Accounts.Membership
        |> Ash.Query.filter(organization_id == ^invitation.organization_id and role == :owner)
        |> Ash.exists?(authorize?: false)

      Zippiker.Accounts.Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: actor.id,
        organization_id: invitation.organization_id,
        role: if(owned?, do: invitation.role, else: :owner)
      })
      |> Ash.create(
        authorize?: false,
        upsert?: true,
        upsert_identity: :unique_member,
        upsert_fields: []
      )
      |> case do
        {:ok, _membership} -> {:ok, invitation}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
