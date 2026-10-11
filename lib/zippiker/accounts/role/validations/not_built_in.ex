defmodule Zippiker.Accounts.Role.Validations.NotBuiltIn do
  @moduledoc "Built-in roles can be edited or reset, not deleted."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if changeset.data.key,
      do: {:error, message: "built-in roles can't be deleted; edit or reset them instead"},
      else: :ok
  end
end
