defmodule Zippiker.Accounts.Role.Actions.SeedDefaults do
  @moduledoc """
  Adds the built-in roles a workspace doesn't have yet (matched by key),
  then gives every plain member who has no role the default roles.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounts.{Membership, MembershipRole, Permissions, Role}

  @impl true
  def run(input, _opts, _context) do
    {:ok, seed(input.arguments.organization_id)}
  end

  @doc "Seeds one workspace; returns the number of roles created."
  def seed(organization_id) do
    opts = [tenant: organization_id, authorize?: false]
    existing = Role |> Ash.read!(opts) |> MapSet.new(& &1.key)

    created =
      for role <- Permissions.default_roles(), role.key not in existing do
        Role
        |> Ash.Changeset.for_create(
          :create,
          Map.take(role, [:name, :description, :permissions, :default?]),
          opts
        )
        |> Ash.Changeset.force_change_attribute(:key, role.key)
        |> Ash.create!()
      end

    assign_defaults(organization_id)
    length(created)
  end

  @doc "Gives members without roles the workspace's default roles."
  def assign_defaults(organization_id, membership_ids \\ nil) do
    defaults =
      Role
      |> Ash.Query.filter(default?)
      |> Ash.read!(tenant: organization_id, authorize?: false)

    members =
      Membership
      |> Ash.Query.filter(organization_id == ^organization_id and role == :member)
      |> then(&if(membership_ids, do: Ash.Query.filter(&1, id in ^membership_ids), else: &1))
      |> Ash.Query.load(:roles)
      |> Ash.read!(authorize?: false)

    for member <- members, member.roles == [], role <- defaults do
      Ash.create!(MembershipRole, %{membership_id: member.id, role_id: role.id},
        authorize?: false
      )
    end

    :ok
  end
end
