defmodule ZippikerWeb.ChecklistLive.Index do
  @moduledoc "Onboarding and offboarding checklists in progress (and done), and starting one."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @kinds ~w(onboarding offboarding)
  @statuses ~w(in_progress completed cancelled)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "On/offboarding")}

  @impl true
  def handle_params(params, _url, socket) do
    kind = if params["kind"] in @kinds, do: String.to_existing_atom(params["kind"])

    status =
      if params["status"] in @statuses,
        do: String.to_existing_atom(params["status"]),
        else: (params["status"] == "all" && nil) || :in_progress

    checklists = HR.list_checklists!(%{kind: kind, status: status}, ash_opts(socket))

    socket =
      socket
      |> assign(kind: kind, status: status, count: length(checklists))
      |> stream(:checklists, checklists, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    opts = ash_opts(socket)

    assign(socket,
      starting: true,
      employees: Enum.map(HR.list_employees!(%{}, opts), &{&1.name, &1.id}),
      templates:
        Enum.map(
          HR.list_checklist_templates!(%{active_only?: true}, opts),
          &{"#{&1.name} (#{&1.kind})", &1.id}
        ),
      employee_id: params["employee_id"]
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :starting, false)

  @impl true
  def handle_event("start", %{"start" => params}, socket) do
    case HR.start_checklist(params, ash_opts(socket)) do
      {:ok, checklist} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{checklist.name} started")
         |> push_navigate(to: ~p"/hr/checklists/#{checklist}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp list_path(params), do: query_path(~p"/hr/checklists", params)

  defp percent(%{tasks_count: 0}), do: 0
  defp percent(%{tasks_count: total, done_count: done}), do: round(done / total * 100)
end
