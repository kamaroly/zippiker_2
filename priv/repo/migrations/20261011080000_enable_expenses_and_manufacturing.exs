defmodule Zippiker.Repo.Migrations.EnableExpensesAndManufacturing do
  @moduledoc "Switches the Expenses and Manufacturing modules on for every existing workspace."
  use Ecto.Migration

  def up do
    for module <- ["expenses", "manufacturing"] do
      execute("""
      UPDATE organizations
      SET enabled_modules = array_append(enabled_modules, '#{module}')
      WHERE NOT ('#{module}' = ANY(enabled_modules))
      """)
    end
  end

  def down do
    execute("""
    UPDATE organizations
    SET enabled_modules = array_remove(array_remove(enabled_modules, 'expenses'), 'manufacturing')
    """)
  end
end
