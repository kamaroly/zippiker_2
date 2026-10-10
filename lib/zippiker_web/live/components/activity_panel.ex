defmodule ZippikerWeb.Components.ActivityPanel do
  @moduledoc """
  Timeline + task list for one record (contact, company, lead or deal).

  A LiveComponent because the same self-contained state (composer, streams,
  tab) is reused on four record pages.

      <.live_component module={ActivityPanel} id="activity" scope={%{deal_id: @deal.id}}
        current_user={@current_user} current_organization={@current_organization} />
  """
  use ZippikerWeb, :live_component

  alias Zippiker.Crm

  @kinds [note: "Note", call: "Call", email: "Email", meeting: "Meeting"]

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns[:loaded?] do
      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(loaded?: true, tab: :activity, kind: :note, kinds: @kinds)
       |> assign_activity_form()
       |> assign_task_form()
       |> load_timeline()
       |> load_tasks()}
    end
  end

  @impl true
  def handle_event("tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  def handle_event("kind", %{"kind" => kind}, socket) do
    kind = Enum.find(Keyword.keys(@kinds), :note, &(to_string(&1) == kind))
    {:noreply, assign(socket, :kind, kind)}
  end

  def handle_event("log", %{"activity" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.activity_form.source,
           params: with_scope(params, socket)
         ) do
      {:ok, activity} ->
        activity = Ash.load!(activity, [:author, :party, :deal], ash_opts(socket.assigns))

        {:noreply,
         socket
         |> stream_insert(:timeline, activity, at: 0)
         |> assign_activity_form()}

      {:error, form} ->
        {:noreply, assign(socket, :activity_form, to_form(form))}
    end
  end

  def handle_event("delete_activity", %{"id" => id}, socket) do
    opts = ash_opts(socket.assigns)
    activity = Ash.get!(Crm.Activity, id, opts)
    Crm.delete_activity!(activity, opts)
    {:noreply, stream_delete(socket, :timeline, activity)}
  end

  def handle_event("add_task", %{"task" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.task_form.source,
           params: with_scope(params, socket)
         ) do
      {:ok, _task} -> {:noreply, socket |> assign_task_form() |> load_tasks()}
      {:error, form} -> {:noreply, assign(socket, :task_form, to_form(form))}
    end
  end

  def handle_event("toggle_task", %{"id" => id}, socket) do
    opts = ash_opts(socket.assigns)
    task = Crm.get_task!(id, opts)

    if task.completed_at,
      do: Crm.reopen_task!(task, opts),
      else: Crm.complete_task!(task, opts)

    {:noreply, load_tasks(socket)}
  end

  defp assign_activity_form(socket) do
    form =
      Crm.Activity
      |> AshPhoenix.Form.for_create(:create,
        as: "activity",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :activity_form, form)
  end

  defp assign_task_form(socket) do
    form =
      Crm.Task
      |> AshPhoenix.Form.for_create(:create,
        as: "task",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, :task_form, form)
  end

  defp load_timeline(socket) do
    activities = Crm.timeline!(socket.assigns.scope, ash_opts(socket.assigns))
    stream(socket, :timeline, activities, reset: true)
  end

  defp load_tasks(socket) do
    tasks = Crm.list_tasks!(Map.put(socket.assigns.scope, :view, :all), ash_opts(socket.assigns))

    socket
    |> assign(:open_tasks, Enum.count(tasks, &(!&1.done?)))
    |> stream(:tasks, tasks, reset: true)
  end

  defp with_scope(params, socket) do
    Enum.reduce(socket.assigns.scope, params, fn {key, value}, params ->
      Map.put(params, to_string(key), value)
    end)
  end

  defp placeholder(:call), do: "What was discussed on the call?"
  defp placeholder(:email), do: "Summarize the email…"
  defp placeholder(:meeting), do: "Meeting notes…"
  defp placeholder(_), do: "Write a note…"
end
