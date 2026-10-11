defmodule Zippiker.Repo.TenantMigrations.DefaultLeaveTypes do
  @moduledoc """
  Gives every team the standard leave types (new teams get them when their
  schema is built). Types a team already has, by name, are left alone.
  """
  use Ecto.Migration

  @types [
    {"Annual Leave", nil, "blue", true},
    {"Compassionate Leave", nil, "violet", true},
    {"Sick Leave", nil, "rose", true},
    {"Maternity Leave", "Leave for mothers", "orange", true},
    {"Paternity Leave", "Leave for fathers", "teal", true},
    {"Conference Leave", "Leave for those attending conference", "amber", true},
    {"Overtime Leave", "For those who already have Saturday or holidays", "emerald", true},
    {"Annual Leave Claim", "To cancel a leave that's already approved", "slate", true}
  ]

  def up do
    for {name, description, color, paid?} <- @types do
      execute("""
      INSERT INTO "#{prefix()}".leave_types
        (name, description, color, "paid?", "requires_approval?", "active?", inserted_at, updated_at)
      SELECT #{literal(name)}, #{literal(description)}, '#{color}', #{paid?}, true, true,
             now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
      WHERE NOT EXISTS (
        SELECT 1 FROM "#{prefix()}".leave_types WHERE lower(name) = lower(#{literal(name)})
      )
      """)
    end
  end

  def down, do: :ok

  defp literal(nil), do: "NULL"
  defp literal(value), do: "'" <> String.replace(value, "'", "''") <> "'"
end
