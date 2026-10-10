defmodule Zippiker.Platform.Checks.ActorAdminsOrganization do
  @moduledoc """
  For generic actions taking an `organization_id` argument: passes when the
  actor is an owner or admin of that workspace.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor is an admin of the given organization"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: %{arguments: %{organization_id: organization_id}}}, _opts)
      when is_binary(organization_id) do
    Zippiker.Accounts.Membership
    |> Ash.Query.filter(
      user_id == ^actor.id and organization_id == ^organization_id and role in [:owner, :admin]
    )
    |> Ash.exists?(authorize?: false)
  end

  def match?(_actor, _context, _opts), do: false
end
