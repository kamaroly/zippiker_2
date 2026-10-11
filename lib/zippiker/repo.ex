defmodule Zippiker.Repo do
  use AshPostgres.Repo,
    otp_app: :zippiker

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext", AshMoney.AshPostgresExtension]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @doc "Every workspace schema, for `mix ash_postgres.migrate --tenants`."
  @impl true
  def all_tenants do
    "SELECT schema_name FROM organizations ORDER BY inserted_at"
    |> query!()
    |> Map.fetch!(:rows)
    |> Enum.map(&hd/1)
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
