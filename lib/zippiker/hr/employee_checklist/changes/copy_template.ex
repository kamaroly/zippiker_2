defmodule Zippiker.HR.EmployeeChecklist.Changes.CopyTemplate do
  @moduledoc """
  Copies the template's tasks onto the new checklist, resolving each
  assignee (the employee's login, their manager's, or the named person; HR
  tasks go to any admin) and due date (`base_date + due_in_days`).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      opts = [tenant: changeset.tenant, authorize?: false]
      template_id = Ash.Changeset.get_attribute(changeset, :template_id)
      employee_id = Ash.Changeset.get_attribute(changeset, :employee_id)

      with id when is_binary(id) <- template_id,
           {:ok, template} <- Zippiker.HR.get_checklist_template(id, opts ++ [load: [:tasks]]),
           {:ok, employee} <-
             Ash.get(Zippiker.HR.Employee, employee_id, opts ++ [load: [:manager]]) do
        base = Ash.Changeset.get_attribute(changeset, :base_date) || Date.utc_today()

        changeset
        |> Ash.Changeset.force_change_attributes(%{name: template.name, kind: template.kind})
        |> Ash.Changeset.after_action(fn changeset, checklist ->
          Enum.each(template.tasks, fn task ->
            Zippiker.HR.ChecklistTask
            |> Ash.Changeset.for_create(
              :create,
              %{
                checklist_id: checklist.id,
                position: task.position,
                title: task.title,
                description: task.description,
                assignee_role: task.assignee_role,
                assignee_id: assignee(task, employee),
                due_on: Date.add(base, task.due_in_days),
                requires_attachment?: task.requires_attachment?
              },
              tenant: changeset.tenant
            )
            |> Ash.create!(authorize?: false)
          end)

          {:ok, checklist}
        end)
      else
        _ ->
          Ash.Changeset.add_error(changeset,
            field: :template_id,
            message: "choose a checklist template"
          )
      end
    end)
  end

  defp assignee(%{assignee_role: :employee}, employee), do: employee.user_id
  defp assignee(%{assignee_role: :manager}, %{manager: %{user_id: id}}), do: id
  defp assignee(%{assignee_role: :user, user_id: id}, _employee), do: id
  defp assignee(_task, _employee), do: nil
end
