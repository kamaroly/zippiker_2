defmodule ZippikerWeb.ChecklistsLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.HR

  setup :register_and_log_in_user

  test "pages render and a new hire's onboarding can be worked through", %{conn: conn, opts: opts} do
    for path <-
          ~w(/hr/checklists /hr/checklists/new /hr/checklist-templates /hr/checklist-templates/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end

    ada = HR.hire_employee!(%{first_name: "Ada", hire_date: Date.utc_today()}, opts)
    [checklist] = HR.list_checklists!(%{employee_id: ada.id}, opts)

    {:ok, view, _html} = live(conn, ~p"/hr/employees/#{ada}")
    assert has_element?(view, "#employee-checklists", "Standard onboarding")

    checklist = HR.get_checklist!(checklist.id, opts ++ [load: [:tasks]])
    simple = Enum.find(checklist.tasks, &(not &1.requires_attachment?))
    proof = Enum.find(checklist.tasks, & &1.requires_attachment?)

    {:ok, view, _html} = live(conn, ~p"/hr/checklists/#{checklist}")
    view |> element("#complete-#{simple.id}") |> render_click()
    assert HR.get_checklist_task!(simple.id, opts).status == :done

    # Attach a file and mark done in one go.
    {:ok, view, _html} = live(conn, ~p"/hr/checklists/#{checklist}/tasks/#{proof.id}")

    file =
      file_input(view, "#task-form", :file, [
        %{name: "contract.pdf", content: "%PDF contract", type: "application/pdf"}
      ])

    render_upload(file, "contract.pdf")
    view |> form("#task-form", %{note: "Signed copy", mark_done: "true"}) |> render_submit()

    done = HR.get_checklist_task!(proof.id, opts ++ [load: [:attachments]])
    assert done.status == :done
    assert [%{name: "contract.pdf", id: file_id}] = done.attachments

    assert response(get(conn, ~p"/hr/checklist-attachments/#{file_id}"), 200) == "%PDF contract"
  end

  test "templates: create one with tasks", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/hr/checklist-templates/new")

    [key] =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#template-tasks > li")
      |> Enum.map(
        &(LazyHTML.attribute(&1, "id")
          |> hd()
          |> String.replace_prefix("template-task-", ""))
      )

    render_submit(view, "save", %{
      "template" => %{
        "name" => "Interns",
        "kind" => "onboarding",
        "default?" => "false",
        "active?" => "true"
      },
      "tasks" => %{
        key => %{"title" => "Meet mentor", "assignee_role" => "manager", "due_in_days" => "1"}
      }
    })

    template = Enum.find(HR.list_checklist_templates!(opts), &(&1.name == "Interns"))
    assert [%{title: "Meet mentor", assignee_role: :manager, due_in_days: 1}] = template.tasks
  end
end
