defmodule Zippiker.HR.Checks.RequestsForThemselves do
  @moduledoc "Passes when the leave request is for the actor's own employee record."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "the request is for the actor's own employee record"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: %Ash.Changeset{} = changeset}, _opts) do
    case Ash.Changeset.get_attribute(changeset, :employee_id) do
      nil ->
        false

      id ->
        case Ash.get(Zippiker.HR.Employee, id, tenant: changeset.tenant, authorize?: false) do
          {:ok, employee} -> employee.user_id == actor.id
          _ -> false
        end
    end
  end

  def match?(_actor, _context, _opts), do: false
end
