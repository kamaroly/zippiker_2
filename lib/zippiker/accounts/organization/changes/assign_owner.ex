defmodule Zippiker.Accounts.Organization.Changes.AssignOwner do
  @moduledoc """
  For workspaces opened from the platform: the user with `owner_email`
  becomes the owner; without an account yet, they're invited, and accepting
  makes them the owner (see `Invitation.Changes.CreateMembership`).
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Zippiker.Accounts.{Invitation, Membership, User}

  @impl true
  def change(changeset, _opts, context) do
    email = Ash.Changeset.get_argument(changeset, :owner_email)

    Ash.Changeset.after_action(changeset, fn _changeset, organization ->
      case User |> Ash.Query.filter(email == ^email) |> Ash.read_one(authorize?: false) do
        {:ok, %User{} = user} ->
          Membership
          |> Ash.Changeset.for_create(:create, %{
            user_id: user.id,
            organization_id: organization.id,
            role: :owner
          })
          |> Ash.create(authorize?: false)
          |> result(organization)

        {:ok, nil} ->
          Invitation
          |> Ash.Changeset.for_create(:create, %{email: email, role: :admin},
            tenant: organization,
            actor: context.actor
          )
          |> Ash.create(authorize?: false)
          |> result(organization)

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp result({:ok, _record}, organization), do: {:ok, organization}
  defp result({:error, error}, _organization), do: {:error, error}
end
