defmodule ZippikerWeb.TaskLive.Index do
  @moduledoc "Task list: today, overdue, upcoming, completed; mine or everyone's."
  use ZippikerWeb, :live_view

  alias Zippiker.Crm

  @views ~w(today overdue upcoming open completed)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tasks")
     |> assign(:members, member_options(socket.assigns))
     |> assign_form()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    view = if params["view"] in @views, do: String.to_existing_atom(params["view"]), else: :open
    everyone? = params["who"] == "all"

    {:noreply,
     socket
     |> assign(view: view, everyone?: everyone?)
     |> load_tasks()}
  end

  @impl true
  def handle_event("add", %{"task" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _task} -> {:noreply, socket |> assign_form() |> load_tasks()}
      {:error, form} -> {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("toggle_task", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    task = Crm.get_task!(id, opts)
    if task.completed_at, do: Crm.reopen_task!(task, opts), else: Crm.complete_task!(task, opts)
    {:noreply, load_tasks(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    task = Crm.get_task!(id, opts)
    Crm.delete_task!(task, opts)
    {:noreply, socket |> stream_delete(:tasks, task) |> update(:count, &(&1 - 1))}
  end

  defp load_tasks(socket) do
    args = %{view: socket.assigns.view}

    args =
      if socket.assigns.everyone?,
        do: args,
        else: Map.put(args, :assignee_id, socket.assigns.current_user.id)

    page = Crm.list_tasks!(args, ash_opts(socket) ++ [page: [limit: 100, count: true]])

    socket
    |> assign(:count, page.count)
    |> stream(:tasks, page.results, reset: true)
  end

  defp assign_form(socket) do
    form =
      Crm.Task
      |> AshPhoenix.Form.for_create(:create,
        as: "task",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"assignee_id" => socket.assigns.current_user.id}
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp related(%{deal: %{} = deal}), do: {deal.title, ~p"/deals/#{deal}"}
  defp related(%{party: %{kind: :person} = party}), do: {party.name, ~p"/contacts/#{party}"}
  defp related(%{party: %{} = party}), do: {party.name, ~p"/companies/#{party}"}
  defp related(%{lead: %{} = lead}), do: {lead.name, ~p"/leads/#{lead}"}
  defp related(_task), do: nil

  defp tasks_path(view, everyone?) do
    params = %{view: view} |> then(&if(everyone?, do: Map.put(&1, :who, "all"), else: &1))
    ~p"/tasks?#{params}"
  end
end
