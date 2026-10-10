defmodule Zippiker.HR.LeaveRequest.Validations.NoOverlap do
  @moduledoc "An employee can't have two pending or approved requests covering the same day."
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    employee_id = Ash.Changeset.get_attribute(changeset, :employee_id)
    from = Ash.Changeset.get_attribute(changeset, :start_date)
    to = Ash.Changeset.get_attribute(changeset, :end_date)

    if Enum.any?([employee_id, from, to], &is_nil/1) do
      :ok
    else
      overlapping? =
        Zippiker.HR.LeaveRequest
        |> Ash.Query.filter(
          employee_id == ^employee_id and status in [:pending, :approved] and
            start_date <= ^to and end_date >= ^from
        )
        |> Ash.exists?(tenant: changeset.tenant, authorize?: false)

      if overlapping?,
        do: {:error, field: :start_date, message: "overlaps another request"},
        else: :ok
    end
  end
end
