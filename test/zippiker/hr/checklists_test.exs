defmodule Zippiker.HR.ChecklistsTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.HR

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    as = &[actor: &1, tenant: organization]
    %{opts: opts, as: as, organization: organization}
  end

  test "every team has standard templates; hiring starts onboarding with assignees and due dates",
       %{opts: opts, as: as, organization: organization} do
    assert [%{kind: :offboarding, default?: true}, %{kind: :onboarding, default?: true}] =
             opts |> HR.list_checklist_templates!() |> Enum.sort_by(& &1.kind)

    manager_user = member_fixture(organization)
    staff_user = member_fixture(organization)
    manager = HR.hire_employee!(%{first_name: "Mia", user_id: manager_user.id}, opts)

    staff =
      HR.hire_employee!(
        %{
          first_name: "Sam",
          user_id: staff_user.id,
          manager_id: manager.id,
          hire_date: ~D[2026-11-02]
        },
        opts
      )

    [checklist] = HR.list_checklists!(%{employee_id: staff.id}, opts)
    assert checklist.kind == :onboarding
    assert checklist.tasks_count == 9

    checklist = HR.get_checklist!(checklist.id, opts ++ [load: [:tasks]])
    contract = Enum.find(checklist.tasks, &(&1.title =~ "contract"))
    assert contract.due_on == ~D[2026-10-30]
    assert contract.assignee_id == nil

    handbook = Enum.find(checklist.tasks, &(&1.title =~ "handbook"))
    assert handbook.assignee_id == staff_user.id
    assert Enum.find(checklist.tasks, &(&1.title =~ "equipment")).assignee_id == manager_user.id

    # The employee sees their tasks; proof is needed before "done".
    assert Enum.any?(HR.my_checklist_tasks!(as.(staff_user)), &(&1.id == handbook.id))
    assert {:error, %Ash.Error.Invalid{}} = HR.complete_checklist_task(handbook, as.(staff_user))

    HR.attach_to_checklist_task!(
      %{task_id: handbook.id, name: "handbook.pdf", path: "x/handbook.pdf"},
      as.(staff_user)
    )

    assert HR.complete_checklist_task!(handbook, %{note: "Signed"}, as.(staff_user)).status ==
             :done

    # Someone else can't do the manager's task; an admin can do anything.
    equipment = Enum.find(checklist.tasks, &(&1.title =~ "equipment"))

    assert {:error, %Ash.Error.Forbidden{}} =
             HR.complete_checklist_task(equipment, as.(staff_user))

    # Finish everything (attachments where needed): the checklist completes.
    for task <- HR.get_checklist!(checklist.id, opts ++ [load: [:tasks]]).tasks,
        task.status == :open do
      if task.requires_attachment?,
        do:
          HR.attach_to_checklist_task!(%{task_id: task.id, name: "f.pdf", path: "x/f.pdf"}, opts)

      HR.complete_checklist_task!(task, opts)
    end

    assert HR.get_checklist!(checklist.id, opts).status == :completed

    # Leaving starts offboarding.
    HR.terminate_employee!(staff, %{termination_date: ~D[2026-12-31]}, opts)

    assert [%{kind: :offboarding, base_date: ~D[2026-12-31]}] =
             HR.list_checklists!(%{employee_id: staff.id, kind: :offboarding}, opts)
  end

  test "reopening a task reopens the checklist", %{opts: opts} do
    {:ok, template} =
      HR.create_checklist_template(
        %{name: "Mini", kind: :onboarding, tasks: [%{title: "Say hi", assignee_role: :hr}]},
        opts
      )

    ada = HR.hire_employee!(%{first_name: "Ada"}, opts)
    checklist = HR.start_checklist!(%{employee_id: ada.id, template_id: template.id}, opts)
    [task] = HR.get_checklist!(checklist.id, opts ++ [load: [:tasks]]).tasks

    task = HR.complete_checklist_task!(task, opts)
    assert HR.get_checklist!(checklist.id, opts).status == :completed
    HR.reopen_checklist_task!(task, opts)
    assert HR.get_checklist!(checklist.id, opts).status == :in_progress
  end
end
