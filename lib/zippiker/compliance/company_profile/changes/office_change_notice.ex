defmodule Zippiker.Compliance.CompanyProfile.Changes.OfficeChangeNotice do
  @moduledoc "A new registered office address must be notified to the Registrar within 14 days."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :registered_office) and
         changeset.data.registered_office not in [nil, ""] do
      Ash.Changeset.after_action(changeset, fn changeset, profile ->
        Zippiker.Compliance.ComplianceTask
        |> Ash.Changeset.for_create(
          :create,
          %{
            profile_id: profile.id,
            kind: :office_change,
            title: "Notify the Registrar of the new registered office",
            description: profile.registered_office,
            due_on: Date.add(Date.utc_today(), 14)
          },
          tenant: changeset.tenant,
          authorize?: false
        )
        |> Ash.create!()

        {:ok, profile}
      end)
    else
      changeset
    end
  end
end
