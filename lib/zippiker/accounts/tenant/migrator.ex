defmodule Zippiker.Accounts.Tenant.Migrator do
  @moduledoc """
  Brings every workspace schema up to date, and moves data left over from
  the old single-schema layout (rows tagged with `organization_id` in
  `public`) into each workspace's schema, then drops those public tables.

  Safe to run repeatedly (`mix zippiker.tenants.migrate`, or
  `Zippiker.Accounts.Tenant.Migrator.run/0` from a release): schemas are
  created only when missing, and a table is copied only while the
  workspace's copy is empty. Also adds missing built-in roles.
  """

  require Logger

  alias Zippiker.Accounts.Tenant
  alias Zippiker.Repo

  def run(opts \\ []) do
    log? = Keyword.get(opts, :log, true)
    teams = query("SELECT id::text, schema_name FROM organizations ORDER BY inserted_at")

    # Public tables left from the single-schema layout: those of resources
    # that now live in team schemas.
    legacy =
      query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ANY($1)",
        [tenant_tables()]
      )
      |> Enum.map(&hd/1)

    for [id, schema] <- teams do
      Tenant.migrate!(schema)
      moved = move(id, schema, legacy)
      if log? and moved > 0, do: Logger.info("Moved #{moved} rows into #{schema}")
    end

    for table <- legacy do
      Ecto.Adapters.SQL.query!(Repo, ~s|DROP TABLE IF EXISTS public."#{table}" CASCADE|, [])
    end

    if log? and legacy != [],
      do: Logger.info("Dropped #{length(legacy)} legacy public tables")

    # Built-in roles for workspaces created before roles existed (and any
    # roles added since); members without a role get the default ones.
    for [id, _schema] <- teams do
      created = Zippiker.Accounts.seed_default_roles!(id, authorize?: false)
      if log? and created > 0, do: Logger.info("Added #{created} built-in roles to #{id}")
    end

    :ok
  end

  @doc "Tables of every resource stored per team (schema-per-tenant)."
  def tenant_tables do
    for domain <- Application.fetch_env!(:zippiker, :ash_domains),
        resource <- Ash.Domain.Info.resources(domain),
        Ash.Resource.Info.multitenancy_strategy(resource) == :context,
        uniq: true,
        do: AshPostgres.DataLayer.Info.table(resource)
  end

  defp move(organization_id, schema, legacy) do
    tables = Enum.filter(legacy, &(&1 in tables(schema)))
    {order, deferred} = copy_order(schema, tables)

    {:ok, moved} =
      Repo.transaction(fn ->
        moved =
          order
          |> Enum.filter(&empty?(schema, &1))
          |> Enum.map(fn table ->
            copy(schema, table, organization_id, Map.get(deferred, table, []))
          end)
          |> Enum.sum()

        for {table, columns} <- deferred, column <- columns do
          Ecto.Adapters.SQL.query!(
            Repo,
            ~s|UPDATE "#{schema}"."#{table}" t SET "#{column}" = p."#{column}" FROM public."#{table}" p WHERE p.id = t.id AND p.organization_id = $1::uuid|,
            [Ecto.UUID.dump!(organization_id)]
          )
        end

        moved
      end)

    moved
  end

  defp copy(schema, table, organization_id, nulled) do
    columns = columns(schema, table)
    target = Enum.map_join(columns, ", ", &~s|"#{&1}"|)

    source =
      Enum.map_join(columns, ", ", fn column ->
        if column in nulled, do: "NULL", else: ~s|"#{column}"|
      end)

    %{num_rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        ~s|INSERT INTO "#{schema}"."#{table}" (#{target}) SELECT #{source} FROM public."#{table}" WHERE organization_id = $1::uuid|,
        [Ecto.UUID.dump!(organization_id)]
      )

    rows
  end

  # Parents before children. Cycles are broken on a nullable foreign key:
  # that column is inserted empty and filled in afterwards.
  defp copy_order(schema, tables) do
    edges =
      query(
        """
        SELECT src.relname, att.attname, dst.relname, NOT att.attnotnull
        FROM pg_constraint con
        JOIN pg_class src ON src.oid = con.conrelid
        JOIN pg_class dst ON dst.oid = con.confrelid
        JOIN pg_namespace ns ON ns.oid = src.relnamespace
        JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = ANY(con.conkey)
        WHERE con.contype = 'f' AND ns.nspname = $1 AND dst.relnamespace = src.relnamespace
        """,
        [schema]
      )
      |> Enum.filter(fn [from, _column, to, _nullable] -> from != to and to in tables end)

    sort(tables, edges, [], %{})
  end

  defp sort([], _edges, order, deferred), do: {Enum.reverse(order), deferred}

  defp sort(remaining, edges, order, deferred) do
    blocked = fn table ->
      Enum.any?(edges, fn [from, _column, to, _nullable] -> from == table and to in remaining end)
    end

    case Enum.find(remaining, &(not blocked.(&1))) do
      nil ->
        [from, column, to, true] =
          Enum.find(edges, fn [from, _column, to, nullable] ->
            nullable and from in remaining and to in remaining
          end)

        edges = Enum.reject(edges, &match?([^from, ^column, ^to, _], &1))
        sort(remaining, edges, order, Map.update(deferred, from, [column], &[column | &1]))

      table ->
        sort(List.delete(remaining, table), edges, [table | order], deferred)
    end
  end

  defp tables(schema) do
    query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = $1 AND table_type = 'BASE TABLE'",
      [schema]
    )
    |> Enum.map(&hd/1)
  end

  defp columns(schema, table) do
    query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = $1 AND table_name = $2 ORDER BY ordinal_position",
      [schema, table]
    )
    |> Enum.map(&hd/1)
  end

  defp empty?(schema, table),
    do: query(~s|SELECT NOT EXISTS (SELECT 1 FROM "#{schema}"."#{table}")|) == [[true]]

  defp query(sql, params \\ []), do: Ecto.Adapters.SQL.query!(Repo, sql, params).rows
end
