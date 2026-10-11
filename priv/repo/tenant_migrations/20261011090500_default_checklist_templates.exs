defmodule Zippiker.Repo.TenantMigrations.DefaultChecklistTemplates do
  @moduledoc "Standard onboarding and offboarding checklists for teams that have none yet."
  use Ecto.Migration

  @templates [
    {"Standard onboarding", "onboarding", "Everything a new joiner needs in their first weeks.",
     [
       {"Signed employment contract", "hr", -3, true},
       {"Copy of ID and KRA PIN certificate", "hr", 0, true},
       {"NSSF, SHA/NHIF and bank details captured", "hr", 3, false},
       {"Email, system logins and access set up", "hr", 0, false},
       {"Laptop, phone and equipment handed over", "manager", 0, false},
       {"Introduced to the team and buddy assigned", "manager", 1, false},
       {"Complete your profile and emergency contact", "employee", 3, false},
       {"Read and sign the staff handbook", "employee", 7, true},
       {"Probation objectives agreed", "manager", 14, false}
     ]},
    {"Standard offboarding", "offboarding", "Leaving well: handover, clearance and final pay.",
     [
       {"Resignation or termination letter on file", "hr", -14, true},
       {"Handover notes for open work", "employee", -3, false},
       {"Exit interview", "manager", -1, false},
       {"Company equipment returned", "employee", 0, false},
       {"System access and email revoked", "hr", 0, false},
       {"Clearance form signed by departments", "hr", 0, true},
       {"Final dues and leave balance paid", "hr", 7, false},
       {"Certificate of service issued", "hr", 7, true}
     ]}
  ]

  def up do
    for {name, kind, description, tasks} <- @templates do
      execute("""
      WITH template AS (
        INSERT INTO "#{prefix()}".checklist_templates
          (name, kind, description, "default?", "active?", inserted_at, updated_at)
        SELECT #{lit(name)}, '#{kind}', #{lit(description)}, true, true,
               now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
        WHERE NOT EXISTS (SELECT 1 FROM "#{prefix()}".checklist_templates WHERE kind = '#{kind}')
        RETURNING id
      )
      INSERT INTO "#{prefix()}".checklist_template_tasks
        (template_id, position, title, assignee_role, due_in_days, "requires_attachment?")
      SELECT template.id, t.position, t.title, t.role, t.due, t.proof
      FROM template, (VALUES #{values(tasks)}) AS t(position, title, role, due, proof)
      """)
    end
  end

  def down, do: :ok

  defp values(tasks) do
    tasks
    |> Enum.with_index()
    |> Enum.map_join(", ", fn {{title, role, due, proof}, index} ->
      "(#{index}, #{lit(title)}, '#{role}', #{due}, #{proof})"
    end)
  end

  defp lit(value), do: "'" <> String.replace(value, "'", "''") <> "'"
end
