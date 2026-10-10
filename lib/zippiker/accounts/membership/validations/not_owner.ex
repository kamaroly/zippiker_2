defmodule Zippiker.Accounts.Membership.Validations.NotOwner do
  @moduledoc "The workspace owner can't be removed or demoted."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if changeset.data.role == :owner,
      do: {:error, field: :role, message: "the owner can't be changed"},
      else: :ok
  end
end
