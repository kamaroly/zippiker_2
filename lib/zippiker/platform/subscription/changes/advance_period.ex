defmodule Zippiker.Platform.Subscription.Changes.AdvancePeriod do
  @moduledoc "Next monthly period; a trialing subscription becomes active once invoiced."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    start = Date.add(changeset.data.current_period_end, 1)

    changeset
    |> Ash.Changeset.force_change_attributes(%{
      current_period_start: start,
      current_period_end: period_end(start)
    })
    |> then(fn changeset ->
      if changeset.data.status == :trialing,
        do: Ash.Changeset.force_change_attribute(changeset, :status, :active),
        else: changeset
    end)
  end

  @doc "A period is one calendar month long: Jan 15 → Feb 14."
  def period_end(start), do: start |> Date.shift(month: 1) |> Date.add(-1)
end
