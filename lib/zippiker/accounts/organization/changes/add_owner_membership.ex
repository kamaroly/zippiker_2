defmodule Zippiker.Accounts.Organization.Changes.AddOwnerMembership do
  @moduledoc "Makes the actor creating an organization its owner."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn _changeset, organization ->
      Zippiker.Accounts.Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: actor.id,
        organization_id: organization.id,
        role: :owner
      })
      |> Ash.create(authorize?: false)
      |> case do
        {:ok, _membership} -> {:ok, organization}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
