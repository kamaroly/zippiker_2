defmodule ZippikerWeb.ChecklistLive.Show do
  @moduledoc """
  One employee's checklist: tasks with assignee and due date, marking
  them done (with a note), and attaching files to them.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:file,
       accept: ~w(.pdf .jpg .jpeg .png .heic .doc .docx .xlsx),
       max_entries: 3,
       max_file_size: 10_000_000
     )
     |> load(id)}
  end

  @impl true
  def handle_params(%{"task_id" => task_id}, _url, socket) do
    {:noreply,
     assign(socket, :task, Enum.find(socket.assigns.checklist.tasks, &(&1.id == task_id)))}
  end

  def handle_params(_params, _url, socket), do: {:noreply, assign(socket, :task, nil)}

  defp load(socket, id) do
    checklist =
      HR.get_checklist!(
        id,
        ash_opts(socket) ++
          [
            load: [
              :tasks_count,
              :done_count,
              employee: [:name, :job_title],
              tasks: [:assignee, :done_by, attachments: [:uploaded_by]]
            ]
          ]
      )

    assign(socket,
      checklist: checklist,
      page_title: "#{checklist.name} · #{checklist.employee.name}"
    )
  end

  @impl true
  def handle_event("complete", %{"id" => id}, socket),
    do: run(socket, id, &HR.complete_checklist_task/2, "Done")

  def handle_event("reopen", %{"id" => id}, socket),
    do: run(socket, id, &HR.reopen_checklist_task/2, "Reopened")

  def handle_event("validate_files", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :file, ref)}

  def handle_event("save_task", params, socket) do
    task = socket.assigns.task
    organization_id = socket.assigns.current_organization.id
    opts = ash_opts(socket)

    results =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
        stored = ZippikerWeb.Uploads.store(path, organization_id, "checklists", entry.client_name)

        {:ok,
         HR.attach_to_checklist_task(
           %{task_id: task.id, name: entry.client_name, path: stored},
           opts
         )}
      end)

    note = params |> Map.get("note", "") |> String.trim()

    completion =
      if params["mark_done"] == "true" and task.status == :open,
        do: HR.complete_checklist_task(task, %{note: if(note == "", do: nil, else: note)}, opts),
        else: {:ok, task}

    case Enum.find(results ++ [completion], &match?({:error, _}, &1)) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved")
         |> load(socket.assigns.checklist.id)
         |> push_patch(to: ~p"/hr/checklists/#{socket.assigns.checklist}")}

      {:error, error} ->
        {:noreply,
         socket |> load(socket.assigns.checklist.id) |> put_flash(:error, error_message(error))}
    end
  end

  def handle_event("remove_file", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> HR.get_checklist_attachment!(opts) |> HR.delete_checklist_attachment(opts) do
      :ok ->
        {:noreply,
         socket |> put_flash(:info, "File removed") |> load(socket.assigns.checklist.id)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("cancel_checklist", _params, socket) do
    case HR.cancel_checklist(socket.assigns.checklist, ash_opts(socket)) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "Checklist cancelled") |> load(socket.assigns.checklist.id)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp run(socket, id, fun, message) do
    task = Enum.find(socket.assigns.checklist.tasks, &(&1.id == id))

    case fun.(task, ash_opts(socket)) do
      {:ok, _task} ->
        {:noreply, socket |> put_flash(:info, message) |> load(socket.assigns.checklist.id)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp can_act?(task, assigns), do: admin?(assigns) or task.assignee_id == assigns.current_user.id

  defp assignee(%{assignee: %{} = user}), do: Format.user_name(user)
  defp assignee(%{assignee_role: :hr}), do: "HR (any admin)"
  defp assignee(%{assignee_role: :manager}), do: "Manager (not linked)"
  defp assignee(%{assignee_role: :employee}), do: "Employee (no login)"
  defp assignee(_task), do: "—"

  defp overdue?(%{status: :open, due_on: %Date{} = due}),
    do: Date.compare(due, Date.utc_today()) == :lt

  defp overdue?(_task), do: false

  defp upload_error(:too_large), do: "Over 10 MB"
  defp upload_error(:not_accepted), do: "Use a PDF, image or Office document"
  defp upload_error(:too_many_files), do: "Up to 3 files at once"
  defp upload_error(_error), do: "Couldn't upload"
end
