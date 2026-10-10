defmodule Zippiker.Accounting.JournalEntry.Changes.Reverse do
  @moduledoc "Copies an entry with debits and credits swapped and links it as the reversal."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    opts = [tenant: changeset.tenant, authorize?: false, load: [:lines, :reversal]]
    entry_id = Ash.Changeset.get_argument(changeset, :entry_id)

    case Zippiker.Accounting.get_journal_entry(entry_id, opts) do
      {:ok, %{reversal: nil} = entry} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          date: Ash.Changeset.get_argument(changeset, :date) || Date.utc_today(),
          memo: "Reversal of #{entry.number}" <> if(entry.memo, do: " · #{entry.memo}", else: ""),
          source: entry.source,
          source_id: entry.source_id,
          source_label: entry.source_label,
          legal_entity_id: entry.legal_entity_id,
          reversal_of_id: entry.id
        })
        |> Ash.Changeset.force_set_argument(
          :lines,
          Enum.map(entry.lines, fn line ->
            %{
              account_id: line.account_id,
              party_id: line.party_id,
              description: line.description,
              debit: line.credit,
              credit: line.debit
            }
          end)
        )

      {:ok, _entry} ->
        Ash.Changeset.add_error(changeset, field: :entry_id, message: "already reversed")

      {:error, _error} ->
        Ash.Changeset.add_error(changeset, field: :entry_id, message: "entry not found")
    end
  end
end
