defmodule Zippiker.Accounts.Tenant do
  @moduledoc """
  Each team (organization) keeps its business data in its own Postgres
  schema, named after the team's domain (`acme.com` → `acme_com`, or
  `team_1`, `team_2`… when no domain was given). Users, organizations,
  memberships, invitations and the platform's billing live in the shared
  `public` schema.

  Tenants travel as the organization struct, its schema name or its id;
  these helpers convert between them.
  """

  require Ash.Query

  alias Zippiker.Repo

  @reserved ~w(public information_schema pg_catalog pg_toast admin www app api zippiker)

  @doc "The Postgres schema of an organization (struct, schema name or id)."
  def schema(%{schema_name: schema}) when is_binary(schema), do: schema

  def schema(id_or_schema) when is_binary(id_or_schema) do
    if uuid?(id_or_schema),
      do:
        lookup("SELECT schema_name FROM organizations WHERE id = $1", [
          Ecto.UUID.dump!(id_or_schema)
        ]),
      else: id_or_schema
  end

  @doc "The organization id behind any tenant value; nil if none."
  def organization_id(nil), do: nil
  def organization_id(%{id: id}), do: id

  def organization_id(value) when is_binary(value) do
    if uuid?(value),
      do: value,
      else: lookup("SELECT id::text FROM organizations WHERE schema_name = $1", [value])
  end

  def organization_id(_tenant), do: nil

  @doc "Schema name for a domain: dots and hyphens become underscores."
  def schema_for_domain(domain), do: String.replace(domain, ~r/[.\-]/, "_")

  @doc "Checks a (lowercased) domain can name a team and its schema."
  def validate_domain(domain) do
    cond do
      not Regex.match?(~r/\A[a-z][a-z0-9.\-]{1,62}\z/, domain) ->
        {:error,
         "use 2–63 lowercase letters, digits, dots or hyphens, starting with a letter (e.g. acme.com)"}

      schema_for_domain(domain) in @reserved or String.starts_with?(domain, "pg_") or
          Regex.match?(~r/\Ateam_\d+\z/, schema_for_domain(domain)) ->
        {:error, "that name is reserved; choose another domain"}

      true ->
        :ok
    end
  end

  @doc "The next automatic team domain: `team_<n>`."
  def next_team_domain do
    "team_#{lookup("SELECT nextval('organizations_team_number_seq')", [])}"
  end

  # Creating a schema adds foreign keys to `public.users`, which locks it;
  # two teams created at once could deadlock, so creation is serialized.
  @lock_key 7_310_042

  @doc """
  Creates the organization's schema with all tenant tables. In tests, a
  pre-built schema from `Zippiker.TenantPool` is used instead (see
  `config :zippiker, :tenant_pool`).
  """
  def create!(organization) do
    name = schema(organization)

    if Repo.in_transaction?() do
      Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [@lock_key])
      AshPostgres.MultiTenancy.create_tenant!(name, Repo)
    else
      Repo.transaction(fn ->
        Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [@lock_key])
        AshPostgres.MultiTenancy.create_tenant!(name, Repo)
      end)
    end

    :ok
  end

  @doc "Runs pending tenant migrations on an existing schema, or creates it."
  def migrate!(schema) do
    if exists?(schema) do
      Ecto.Migrator.run(Repo, tenant_migrations_path(), :up,
        all: true,
        prefix: schema,
        log: false
      )

      :ok
    else
      create!(schema)
    end
  end

  def exists?(schema),
    do: lookup("SELECT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = $1)", [schema])

  def tenant_migrations_path,
    do: Application.app_dir(:zippiker, "priv/repo/tenant_migrations")

  defp uuid?(value), do: match?({:ok, _}, Ecto.UUID.cast(value)) and String.length(value) == 36

  defp lookup(sql, params) do
    case Ecto.Adapters.SQL.query!(Repo, sql, params).rows do
      [[value]] -> value
      _ -> nil
    end
  end
end
