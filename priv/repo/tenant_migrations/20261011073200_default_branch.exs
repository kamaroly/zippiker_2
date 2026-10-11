defmodule Zippiker.Repo.TenantMigrations.DefaultBranch do
  @moduledoc """
  Every team gets a default branch ("Head office", HQ), and records from
  before branches existed are assigned to it.
  """
  use Ecto.Migration

  @tables ~w(quotes sales_orders invoices rfqs purchase_orders bills employees warehouses
             expense_claims production_orders journal_entries)

  def up do
    execute("""
    INSERT INTO "#{prefix()}".branches (name, code, "default?", "active?", inserted_at, updated_at)
    SELECT 'Head office', 'HQ', true, true, now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
    WHERE NOT EXISTS (SELECT 1 FROM "#{prefix()}".branches WHERE "default?")
    """)

    for table <- @tables do
      execute("""
      UPDATE "#{prefix()}".#{table}
      SET branch_id = (SELECT id FROM "#{prefix()}".branches WHERE "default?" LIMIT 1)
      WHERE branch_id IS NULL
      """)
    end
  end

  def down, do: :ok
end
