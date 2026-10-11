defmodule Zippiker.HR.LeaveRequest.Validations.PolicyRules do
  @moduledoc """
  The leave policy's request rules: a supporting file when it requires
  one, and no start date in the past unless backdating is allowed (admins
  can always record past leave).
  """
  use Ash.Resource.Validation

  alias Zippiker.Accounts.Checks.Membership
  alias Zippiker.HR.Entitlement

  @impl true
  def validate(changeset, _opts, context) do
    employee_id = Ash.Changeset.get_attribute(changeset, :employee_id)
    type_id = Ash.Changeset.get_attribute(changeset, :leave_type_id)
    start = Ash.Changeset.get_attribute(changeset, :start_date)
    opts = [tenant: changeset.tenant, authorize?: false]

    policy = employee_id && type_id && Entitlement.policy_for(employee_id, type_id, opts)

    cond do
      is_nil(policy) ->
        :ok

      policy.requires_attachment? and
          Ash.Changeset.get_attribute(changeset, :attachment_name) in [nil, ""] ->
        {:error,
         field: :attachment_name, message: "attach a supporting document (#{policy.name})"}

      not policy.allow_backdated? and match?(%Date{}, start) and
        Date.compare(start, Date.utc_today()) == :lt and not admin?(context, changeset) ->
        {:error, field: :start_date, message: "#{policy.name} can't be requested for past dates"}

      true ->
        :ok
    end
  end

  defp admin?(%{actor: actor}, changeset) when not is_nil(actor),
    do: Membership.role(actor, %{changeset: changeset}) in [:owner, :admin]

  defp admin?(_context, _changeset), do: false
end
