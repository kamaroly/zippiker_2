defmodule Zippiker.HR.Employee.Changes.UpdateParty do
  @moduledoc "Keeps the person's name, email, phone and job title in step with the employee form."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, employee ->
      params =
        [:first_name, :last_name, :email, :phone]
        |> Enum.filter(&(Ash.Changeset.fetch_argument(changeset, &1) != :error))
        |> Map.new(&{&1, Ash.Changeset.get_argument(changeset, &1)})
        |> Map.put(:job_title, employee.job_title)

      opts = [tenant: changeset.tenant, authorize?: false]

      with {:ok, party} <- Zippiker.Parties.get_party(employee.party_id, opts),
           {:ok, _party} <-
             party
             |> Ash.Changeset.for_update(:update, params, opts)
             |> Ash.update(authorize?: false) do
        {:ok, employee}
      end
    end)
  end
end
