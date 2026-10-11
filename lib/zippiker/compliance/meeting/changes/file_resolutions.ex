defmodule Zippiker.Compliance.Meeting.Changes.FileResolutions do
  @moduledoc "Each passed special resolution goes on the calendar: file it with the Registrar within 30 days."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, meeting ->
      opts = [tenant: changeset.tenant, authorize?: false]
      meeting = Ash.load!(meeting, :resolutions, opts ++ [reuse_values?: false])

      for resolution <- meeting.resolutions,
          resolution.kind == :special and resolution.passed? and meeting.status == :held do
        Zippiker.Compliance.ComplianceTask
        |> Ash.Changeset.for_create(
          :create,
          %{
            profile_id: meeting.profile_id,
            kind: :resolution_filing,
            title: "File special resolution: #{String.slice(resolution.text, 0, 80)}",
            due_on: Date.add(meeting.held_on, 30),
            period: "RES-#{resolution.id}"
          },
          opts
        )
        |> Ash.create!(upsert?: true, upsert_identity: :one_per_period, upsert_fields: [])
      end

      {:ok, meeting}
    end)
  end
end
