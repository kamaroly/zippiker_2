defmodule Zippiker.Parties.Party.Validations.EmployerIsOrganization do
  @moduledoc "Only people can have an employer, and it must be an organization."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    employer_id = Ash.Changeset.get_attribute(changeset, :employer_id)

    cond do
      is_nil(employer_id) ->
        :ok

      Ash.Changeset.get_attribute(changeset, :kind) != :person ->
        {:error, field: :employer_id, message: "only people can have an employer"}

      true ->
        case Zippiker.Parties.get_party(employer_id, tenant: changeset.tenant, authorize?: false) do
          {:ok, %{kind: :organization}} -> :ok
          _ -> {:error, field: :employer_id, message: "must be a company"}
        end
    end
  end
end
