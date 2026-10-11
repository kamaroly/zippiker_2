defmodule Zippiker.Accounts.Role.Validations.KnownPermissions do
  @moduledoc "Every permission on a role must exist in the catalog."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    permissions = Ash.Changeset.get_attribute(changeset, :permissions) || []

    case permissions -- Zippiker.Accounts.Permissions.keys() do
      [] ->
        :ok

      unknown ->
        {:error, field: :permissions, message: "unknown permissions: #{Enum.join(unknown, ", ")}"}
    end
  end

  # The new list is a plain value on the changeset, so the same check works
  # for atomic updates.
  @impl true
  def atomic(changeset, opts, context), do: validate(changeset, opts, context)
end
