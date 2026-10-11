defmodule Zippiker.Accounts.Changes.SetBranch do
  @moduledoc """
  Gives a new record a branch when none is chosen: the branch of the
  document it was made from (`from: [quote_id: Zippiker.Sales.Quote, …]`),
  else the team's default branch.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      if Ash.Changeset.get_attribute(changeset, :branch_id) do
        changeset
      else
        tenant_opts = [tenant: changeset.tenant, authorize?: false]

        branch_id =
          Enum.find_value(Keyword.get(opts, :from, []), fn {field, resource} ->
            with id when is_binary(id) <- Ash.Changeset.get_attribute(changeset, field),
                 {:ok, %{branch_id: branch_id}} <- Ash.get(resource, id, tenant_opts),
                 do: branch_id,
                 else: (_ -> nil)
          end) || Zippiker.Accounts.default_branch!(tenant_opts).id

        Ash.Changeset.force_change_attribute(changeset, :branch_id, branch_id)
      end
    end)
  end
end
