defmodule Zippiker.HR.LeavePolicy.Validations.CategorySettings do
  @moduledoc "Accruing policies need how many days and how often; a threshold needs an action."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)

    cond do
      get.(:category) == :accrual and is_nil(get.(:accrual_days)) ->
        {:error, field: :accrual_days, message: "how many days are earned each period?"}

      get.(:category) == :accrual and is_nil(get.(:accrual_frequency)) ->
        {:error, field: :accrual_frequency, message: "choose how often days are earned"}

      get.(:overdue_action) != :none and is_nil(get.(:review_threshold_days)) ->
        {:error, field: :review_threshold_days, message: "set after how many days it applies"}

      true ->
        :ok
    end
  end
end
