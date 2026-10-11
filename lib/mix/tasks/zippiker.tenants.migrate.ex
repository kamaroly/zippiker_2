defmodule Mix.Tasks.Zippiker.Tenants.Migrate do
  @shortdoc "Creates/migrates workspace schemas and moves legacy public data into them"
  @moduledoc """
  Runs `Zippiker.Accounts.Tenant.Migrator`: every workspace gets its own
  schema with the latest tenant migrations, data from the old
  single-schema layout is moved in, and the old public tables are dropped.

      mix zippiker.tenants.migrate          # runs after `mix ecto.migrate` (alias)
      mix zippiker.tenants.migrate --quiet
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.config")

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Zippiker.Repo, fn _repo ->
        Zippiker.Accounts.Tenant.Migrator.run(log: "--quiet" not in args)
      end)

    :ok
  end
end
