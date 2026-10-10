defmodule Zippiker.HR.Employee.Validations.ManagerChain do
  @moduledoc "Nobody can report to themselves, directly or through their own reports."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    manager_id = Ash.Changeset.get_attribute(changeset, :manager_id)
    self_id = changeset.data.id

    cond do
      is_nil(manager_id) -> :ok
      not is_nil(self_id) and manager_id == self_id -> error()
      is_nil(self_id) -> :ok
      self_id in chain(manager_id, changeset.tenant, []) -> error()
      true -> :ok
    end
  end

  defp error, do: {:error, field: :manager_id, message: "would create a reporting loop"}

  # Managers above `id`, stopping at the top or after 50 levels.
  defp chain(nil, _tenant, acc), do: acc
  defp chain(_id, _tenant, acc) when length(acc) > 50, do: acc

  defp chain(id, tenant, acc) do
    case Ash.get(Zippiker.HR.Employee, id, tenant: tenant, authorize?: false) do
      {:ok, employee} -> chain(employee.manager_id, tenant, [id | acc])
      _ -> [id | acc]
    end
  end
end
