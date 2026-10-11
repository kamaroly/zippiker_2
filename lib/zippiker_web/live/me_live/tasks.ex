defmodule ZippikerWeb.MeLive.Tasks do
  @moduledoc "Self-service: onboarding/offboarding tasks assigned to me (HR tasks too, for admins)."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    tasks =
      HR.my_checklist_tasks!(
        %{include_hr?: can?(socket.assigns, "checklist_tasks.manage")},
        ash_opts(socket)
      )

    {:ok, assign(socket, page_title: "My tasks", tasks: tasks)}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  defp overdue?(%{due_on: %Date{} = due}), do: Date.compare(due, Date.utc_today()) == :lt
  defp overdue?(_task), do: false
end
