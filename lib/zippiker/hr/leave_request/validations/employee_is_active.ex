defmodule Zippiker.HR.LeaveRequest.Validations.EmployeeIsActive do
  @moduledoc "People who have left can't request leave."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    with id when is_binary(id) <- Ash.Changeset.get_attribute(changeset, :employee_id),
         {:ok, %{status: :terminated}} <-
           Ash.get(Zippiker.HR.Employee, id, tenant: changeset.tenant, authorize?: false) do
      {:error, field: :employee_id, message: "has left the organization"}
    else
      _ -> :ok
    end
  end
end
