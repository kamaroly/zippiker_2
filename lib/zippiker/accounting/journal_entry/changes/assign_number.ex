defmodule Zippiker.Accounting.JournalEntry.Changes.AssignNumber do
  @moduledoc "Numbers the entry from the legal entity's journal sequence (`JE-2026-0001`)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      opts = [tenant: changeset.tenant, authorize?: false]
      entity_id = Ash.Changeset.get_attribute(changeset, :legal_entity_id)
      number = Zippiker.Accounts.next_document_number!(entity_id, :journal, "JE", opts)
      Ash.Changeset.force_change_attribute(changeset, :number, number)
    end)
  end
end
