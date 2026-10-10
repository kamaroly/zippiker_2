defmodule Zippiker.Crm.Deal.Changes.PlaceOnTop do
  @moduledoc "New deals appear first in their board column."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :position) do
      changeset
    else
      Ash.Changeset.force_change_attribute(
        changeset,
        :position,
        -System.system_time(:millisecond) / 1
      )
    end
  end
end
