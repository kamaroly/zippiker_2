defmodule Zippiker.Accounting.JournalLine.Changes.Defaults do
  @moduledoc """
  A blank debit or credit means zero, and a line without a date takes today's
  (entries always pass their own date; this only matters for form validation).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Enum.reduce(
      [debit: Decimal.new(0), credit: Decimal.new(0), date: Date.utc_today()],
      changeset,
      fn {field, default}, changeset ->
        if is_nil(Ash.Changeset.get_attribute(changeset, field)),
          do: Ash.Changeset.force_change_attribute(changeset, field, default),
          else: changeset
      end
    )
  end
end
