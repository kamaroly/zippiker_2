defmodule Zippiker.Accounts.Checks.Permitted do
  @moduledoc """
  The role gate in front of every restricted action (see
  `Zippiker.Accounts.Permissions`): a plain member needs the permission
  covering the action. Owners, admins, people outside the workspace (other
  policies decide for them), unrestricted actions and actions anyone may
  do for themselves pass.
  """
  use Ash.Policy.SimpleCheck

  alias Zippiker.Accounts.Checks.Membership
  alias Zippiker.Accounts.Permissions

  @impl true
  def describe(_opts), do: "actor's roles allow this action"

  @impl true
  def match?(actor, %{resource: resource, action: %{name: name}} = context, _opts) do
    case Permissions.for_action(resource, name) do
      nil ->
        true

      key ->
        Permissions.level(resource, name) == :open or
          case Membership.permissions(actor, context) do
            nil -> true
            :all -> true
            granted -> MapSet.member?(granted, key)
          end
    end
  end

  def match?(_actor, _context, _opts), do: true
end
