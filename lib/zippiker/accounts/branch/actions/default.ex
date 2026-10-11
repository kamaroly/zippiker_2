defmodule Zippiker.Accounts.Branch.Actions.Default do
  @moduledoc "Returns the default branch, creating \"Head office\" (HQ) if there is none."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounts.Branch

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]

    case find(opts) do
      {:ok, nil} ->
        # A concurrent request may win the unique index; then read its row.
        with {:error, _} <-
               Branch
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Head office", code: "HQ", default?: true},
                 opts
               )
               |> Ash.create(),
             do: find(opts)

      other ->
        other
    end
  end

  defp find(opts) do
    Branch
    |> Ash.Query.filter(default? == true)
    |> Ash.Query.limit(1)
    |> Ash.read_one(opts)
  end
end
