defmodule Zippiker.Accounts.Checks.ActorIsAdmin do
  @moduledoc """
  Passes when the actor is an owner or admin of the current organization,
  or a member whose roles grant the permission covering this action (so a
  role can open up an admin-only action, e.g. "Approve bills").
  """
  use Ash.Policy.SimpleCheck

  alias Zippiker.Accounts.Checks.Membership
  alias Zippiker.Accounts.Permissions

  @impl true
  def describe(_opts), do: "actor is an admin of the current organization (or has the permission)"

  @impl true
  def match?(actor, context, _opts) do
    Membership.role(actor, context) in [:owner, :admin] or granted?(actor, context)
  end

  defp granted?(actor, %{resource: resource, action: %{name: name}} = context) do
    with key when is_binary(key) <- Permissions.for_action(resource, name),
         %MapSet{} = granted <- Membership.permissions(actor, context) do
      MapSet.member?(granted, key)
    else
      _ -> false
    end
  end

  defp granted?(_actor, _context), do: false
end
