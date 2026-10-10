defmodule Zippiker.Accounts.Invitation.Changes.CreateMembership do
  @moduledoc "Adds the accepting user to the workspace (or keeps an existing membership)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      Zippiker.Accounts.Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: actor.id,
        organization_id: invitation.organization_id,
        role: invitation.role
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
