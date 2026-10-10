defmodule Zippiker.Accounting.JournalEntry.Changes.SetLegalEntity do
  @moduledoc "Books into the workspace's default legal entity unless one is given."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :legal_entity_id) do
      changeset
    else
      entity =
        Zippiker.Accounts.default_legal_entity!(tenant: changeset.tenant, authorize?: false)

      Ash.Changeset.force_change_attribute(changeset, :legal_entity_id, entity.id)
    end
  end
end
