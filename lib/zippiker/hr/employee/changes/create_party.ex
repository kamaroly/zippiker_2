defmodule Zippiker.HR.Employee.Changes.CreateParty do
  @moduledoc """
  New hires become a person in `Zippiker.Parties` (tagged `:employee`) built
  from the name, email and phone arguments, unless an existing `party_id` is given.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    cond do
      Ash.Changeset.get_attribute(changeset, :party_id) ->
        changeset

      blank?(Ash.Changeset.get_argument(changeset, :first_name)) ->
        Ash.Changeset.add_error(changeset, field: :first_name, message: "is required")

      true ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          arg = &Ash.Changeset.get_argument(changeset, &1)

          party =
            Zippiker.Parties.Party
            |> Ash.Changeset.for_create(
              :create,
              %{
                kind: :person,
                first_name: arg.(:first_name),
                last_name: arg.(:last_name),
                email: arg.(:email),
                phone: arg.(:phone),
                job_title: Ash.Changeset.get_attribute(changeset, :job_title),
                roles: [:employee]
              },
              tenant: changeset.tenant,
              authorize?: false
            )
            |> Ash.create!(authorize?: false)

          Ash.Changeset.force_change_attribute(changeset, :party_id, party.id)
        end)
    end
  end

  defp blank?(value), do: value in [nil, ""]
end
