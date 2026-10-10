defmodule Zippiker.Accounts.Checks.ActorIsSuperAdmin do
  @moduledoc "Passes when the actor is a platform super admin."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a platform super admin"

  @impl true
  def match?(%{super_admin?: true}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
