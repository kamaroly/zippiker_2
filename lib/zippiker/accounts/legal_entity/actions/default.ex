defmodule Zippiker.Accounts.LegalEntity.Actions.Default do
  @moduledoc "Returns the default legal entity, creating it from the organization if missing."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Accounts.LegalEntity

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]

    case find_default(opts) do
      {:ok, nil} ->
        # A concurrent request may win the unique index; then read its row.
        with {:error, _} <- create_default(input.tenant, opts), do: find_default(opts)

      other ->
        other
    end
  end

  defp find_default(opts) do
    LegalEntity
    |> Ash.Query.filter(default? == true)
    |> Ash.Query.limit(1)
    |> Ash.read_one(opts)
  end

  defp create_default(tenant, opts) do
    organization =
      Zippiker.Accounts.get_organization!(Zippiker.Accounts.Tenant.organization_id(tenant),
        authorize?: false
      )

    LegalEntity
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: organization.name,
        legal_name: organization.name,
        currency: organization.currency,
        default?: true
      },
      opts
    )
    |> Ash.create()
  end
end
