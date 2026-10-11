defmodule Zippiker.Compliance.Changes.RefreshCalendar do
  @moduledoc "Adds the company's recurring obligations (annual returns, AGMs) after it's saved."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, profile ->
      Zippiker.Compliance.Calendar.refresh(profile, changeset.tenant)
      {:ok, profile}
    end)
  end
end
