defmodule Zippiker.Accounts.Organization.Changes.CreateTenant do
  @moduledoc """
  Creates the new team's Postgres schema (with all tenant tables) right
  after it's saved. With `config :zippiker, :tenant_pool` (tests), a
  pre-built schema is checked out instead of building one.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Application.get_env(:zippiker, :tenant_pool) do
      nil ->
        Ash.Changeset.after_action(changeset, fn _changeset, organization ->
          Zippiker.Accounts.Tenant.create!(organization)
          {:ok, organization}
        end)

      pool ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          Ash.Changeset.force_change_attribute(changeset, :schema_name, pool.checkout())
        end)
    end
  end
end
