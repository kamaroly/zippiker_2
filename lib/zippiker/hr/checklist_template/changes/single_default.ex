defmodule Zippiker.HR.ChecklistTemplate.Changes.SingleDefault do
  @moduledoc "One default template per kind: making one default takes the flag from the other."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :default?) and
         Ash.Changeset.changing_attribute?(changeset, :default?) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        kind = Ash.Changeset.get_attribute(changeset, :kind)

        Zippiker.HR.ChecklistTemplate
        |> Ash.Query.filter(default? == true and kind == ^kind)
        |> Ash.bulk_update!(:update, %{default?: false},
          tenant: changeset.tenant,
          authorize?: false,
          strategy: [:stream]
        )

        changeset
      end)
    else
      changeset
    end
  end
end
