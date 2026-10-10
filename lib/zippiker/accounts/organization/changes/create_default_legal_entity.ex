defmodule Zippiker.Accounts.Organization.Changes.CreateDefaultLegalEntity do
  @moduledoc "Every new workspace starts with one legal entity named after it."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, organization ->
      case Zippiker.Accounts.default_legal_entity(tenant: organization, authorize?: false) do
        {:ok, _entity} -> {:ok, organization}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
