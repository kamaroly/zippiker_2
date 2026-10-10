defmodule Zippiker.Sales.Changes.SetLegalEntity do
  @moduledoc """
  Defaults the legal entity (issuer, buyer or employer) and, for documents
  with a `currency`, copies the entity's currency onto them.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    opts = [tenant: changeset.tenant, authorize?: false]

    entity =
      case Ash.Changeset.get_attribute(changeset, :legal_entity_id) do
        nil -> Zippiker.Accounts.default_legal_entity!(opts)
        id -> Zippiker.Accounts.get_legal_entity!(id, opts)
      end

    changeset = Ash.Changeset.force_change_attribute(changeset, :legal_entity_id, entity.id)

    if Ash.Resource.Info.attribute(changeset.resource, :currency),
      do: Ash.Changeset.force_change_attribute(changeset, :currency, entity.currency),
      else: changeset
  end
end
