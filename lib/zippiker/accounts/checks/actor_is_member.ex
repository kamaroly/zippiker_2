defmodule Zippiker.Accounts.Checks.ActorIsMember do
  @moduledoc """
  Passes when the actor belongs to the organization the request is scoped to
  (the Ash tenant). Used by every tenant-scoped resource.
  """
  use Ash.Policy.SimpleCheck

  alias Zippiker.Accounts.Checks.Membership

  @impl true
  def describe(_opts), do: "actor is a member of the current organization"

  @impl true
  def match?(actor, context, _opts), do: Membership.role(actor, context) != nil
end
