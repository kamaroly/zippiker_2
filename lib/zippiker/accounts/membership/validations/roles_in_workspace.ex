defmodule Zippiker.Accounts.Membership.Validations.RolesInWorkspace do
  @moduledoc "A member can only be given roles of their own workspace."
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    ids = Ash.Changeset.get_argument(changeset, :role_ids) || []
    organization_id = changeset.data.organization_id

    found =
      Zippiker.Accounts.Role
      |> Ash.Query.filter(id in ^ids)
      |> Ash.count!(tenant: organization_id, authorize?: false)

    if found == length(Enum.uniq(ids)),
      do: :ok,
      else: {:error, field: :role_ids, message: "unknown role"}
  end
end
