defmodule ZippikerWeb.ChecklistLive.Templates do
  @moduledoc """
  Onboarding and offboarding checklist templates: the tasks, who does each
  (HR, the manager, the employee, a named person), when, and whether proof
  is needed. The default of each kind starts automatically.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @roles [
    {"HR (any admin)", "hr"},
    {"Manager", "manager"},
    {"Employee", "employee"},
    {"Specific person", "user"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Checklist templates",
       roles: @roles,
       members: member_options(socket.assigns)
     )
     |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    assign(socket,
      template: nil,
      editing?: true,
      fields: %{
        "name" => "",
        "kind" => params["kind"] || "onboarding",
        "description" => "",
        "default?" => "false",
        "active?" => "true"
      },
      tasks: [task_row(%{})]
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    template = Enum.find(socket.assigns.templates, &(&1.id == id))

    assign(socket,
      template: template,
      editing?: true,
      fields: %{
        "name" => template.name,
        "kind" => to_string(template.kind),
        "description" => template.description || "",
        "default?" => to_string(template.default?),
        "active?" => to_string(template.active?)
      },
      tasks: Enum.map(template.tasks, &task_row/1)
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, template: nil, editing?: false)

  defp task_row(task) do
    %{
      "key" => Map.get(task, :id) || Ash.UUID.generate(),
      "title" => Map.get(task, :title) || "",
      "description" => Map.get(task, :description) || "",
      "assignee_role" => to_string(Map.get(task, :assignee_role) || :hr),
      "user_id" => Map.get(task, :user_id) || "",
      "due_in_days" => to_string(Map.get(task, :due_in_days) || 0),
      "requires_attachment?" => to_string(Map.get(task, :requires_attachment?) || false)
    }
  end

  @impl true
  def handle_event("change", params, socket), do: {:noreply, assign_params(socket, params)}

  def handle_event("add_task", _params, socket),
    do: {:noreply, update(socket, :tasks, &(&1 ++ [task_row(%{})]))}

  def handle_event("remove_task", %{"key" => key}, socket),
    do:
      {:noreply, update(socket, :tasks, fn tasks -> Enum.reject(tasks, &(&1["key"] == key)) end)}

  def handle_event("save", params, socket) do
    socket = assign_params(socket, params)
    fields = socket.assigns.fields

    tasks =
      socket.assigns.tasks
      |> Enum.reject(&(String.trim(&1["title"]) == ""))
      |> Enum.with_index()
      |> Enum.map(fn {task, index} ->
        %{
          "position" => index,
          "title" => task["title"],
          "description" => blank_to_nil(task["description"]),
          "assignee_role" => task["assignee_role"],
          "user_id" => if(task["assignee_role"] == "user", do: blank_to_nil(task["user_id"])),
          "due_in_days" => task["due_in_days"],
          "requires_attachment?" => task["requires_attachment?"] == "true"
        }
      end)

    attrs = %{
      name: fields["name"],
      description: blank_to_nil(fields["description"]),
      default?: fields["default?"] == "true",
      active?: fields["active?"] == "true",
      tasks: tasks
    }

    result =
      case socket.assigns.template do
        nil ->
          HR.create_checklist_template(Map.put(attrs, :kind, fields["kind"]), ash_opts(socket))

        template ->
          HR.update_checklist_template(template, attrs, ash_opts(socket))
      end

    case result do
      {:ok, _template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Template saved")
         |> load()
         |> push_patch(to: ~p"/hr/checklist-templates")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.id == id))

    case HR.delete_checklist_template(template, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Template deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp assign_params(socket, params) do
    fields = Map.merge(socket.assigns.fields, Map.get(params, "template", %{}))
    rows = Map.get(params, "tasks", %{})

    tasks =
      Enum.map(socket.assigns.tasks, fn task ->
        Map.merge(
          task,
          Map.take(
            Map.get(rows, task["key"], %{}),
            ~w(title description assignee_role user_id due_in_days requires_attachment?)
          )
        )
      end)

    assign(socket, fields: fields, tasks: tasks)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp load(socket),
    do: assign(socket, :templates, HR.list_checklist_templates!(ash_opts(socket)))

  defp role_label(:hr), do: "HR"
  defp role_label(:user), do: "Named person"
  defp role_label(role), do: Format.humanize(role)

  defp due_label(0), do: "on the day"
  defp due_label(days) when days < 0, do: "#{-days}d before"
  defp due_label(days), do: "+#{days}d"
end
