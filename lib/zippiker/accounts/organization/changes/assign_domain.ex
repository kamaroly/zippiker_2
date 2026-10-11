defmodule Zippiker.Accounts.Organization.Changes.AssignDomain do
  @moduledoc """
  Normalizes the team's domain (lowercase; letters, digits, dots and
  hyphens; starting with a letter) or, when it's blank, numbers the team
  `team_1`, `team_2`… Sets `schema_name` from it (dots and hyphens become
  underscores), the schema holding the team's data.
  """
  use Ash.Resource.Change

  alias Zippiker.Accounts.Tenant

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :domain) do
      blank when blank in [nil, ""] ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          domain = Tenant.next_team_domain()

          Ash.Changeset.force_change_attributes(changeset, %{
            domain: domain,
            schema_name: Tenant.schema_for_domain(domain)
          })
        end)

      domain ->
        domain = domain |> String.trim() |> String.downcase()

        case Tenant.validate_domain(domain) do
          :ok ->
            Ash.Changeset.force_change_attributes(changeset, %{
              domain: domain,
              schema_name: Tenant.schema_for_domain(domain)
            })

          {:error, message} ->
            Ash.Changeset.add_error(changeset, field: :domain, message: message)
        end
    end
  end
end
