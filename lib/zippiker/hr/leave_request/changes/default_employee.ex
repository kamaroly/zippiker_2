defmodule Zippiker.HR.LeaveRequest.Changes.DefaultEmployee do
  @moduledoc "Without an employee, the request is for the actor's own employee record."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, %{actor: %{id: actor_id}}) do
    if Ash.Changeset.get_attribute(changeset, :employee_id) do
      changeset
    else
      Zippiker.HR.Employee
      |> Ash.Query.filter(user_id == ^actor_id)
      |> Ash.read_one(tenant: changeset.tenant, authorize?: false)
      |> case do
        {:ok, %{id: id}} ->
          Ash.Changeset.force_change_attribute(changeset, :employee_id, id)

        _ ->
          Ash.Changeset.add_error(changeset,
            field: :employee_id,
            message: "you don't have an employee record yet; ask an admin to link your user"
          )
      end
    end
  end

  def change(changeset, _opts, _context), do: changeset
end
