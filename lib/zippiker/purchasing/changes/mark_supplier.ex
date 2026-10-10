defmodule Zippiker.Purchasing.Changes.MarkSupplier do
  @moduledoc "Tags the supplier party with the `:supplier` role the first time we buy from them."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, document ->
      opts = [tenant: changeset.tenant, authorize?: false]

      with {:ok, party} <- Zippiker.Parties.get_party(document.supplier_id, opts),
           false <- :supplier in party.roles,
           {:ok, _party} <-
             party
             |> Ash.Changeset.for_update(:add_role, %{role: :supplier}, opts)
             |> Ash.update(authorize?: false) do
        {:ok, document}
      else
        {:error, error} -> {:error, error}
        _already_supplier -> {:ok, document}
      end
    end)
  end
end
