defmodule Zippiker.Accounts.Checks.ActorIsAdmin do
  @moduledoc "Passes when the actor is an owner or admin of the current organization."
  use Ash.Policy.SimpleCheck

  alias Zippiker.Accounts.Checks.Membership

  @impl true
  def describe(_opts), do: "actor is an admin of the current organization"

  @impl true
  def match?(actor, context, _opts), do: Membership.role(actor, context) in [:owner, :admin]
end
