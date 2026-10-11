defmodule ZippikerWeb.ComplianceLive.Filings do
  @moduledoc """
  The filing calendar: annual returns, notices to the Registrar and other
  statutory deadlines, marked filed with the receipt reference.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Filing calendar")}

  @impl true
  def handle_params(params, _url, socket) do
    socket = Scope.assign_profile(socket, params)

    {:noreply,
     socket
     |> assign(
       show: if(params["show"] == "all", do: :all, else: :open),
       modal: params["modal"],
       task_id: params["task"]
     )
     |> load()}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :tasks, [])

  defp load(socket) do
    assign(
      socket,
      :tasks,
      Compliance.filing_calendar!(
        socket.assigns.profile.id,
        %{open_only?: socket.assigns.show == :open},
        ash_opts(socket)
      )
    )
  end

  @impl true
  def handle_event("complete", %{"filing" => params}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == socket.assigns.task_id))

    case Compliance.complete_compliance_task(task, params, ash_opts(socket)) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "Marked as filed") |> push_patch(to: ~p"/compliance/filings")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("reopen", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == id))
    Compliance.reopen_compliance_task!(task, ash_opts(socket))
    {:noreply, socket |> put_flash(:info, "Reopened") |> load()}
  end

  def handle_event("add", %{"filing" => params}, socket) do
    params = Map.merge(params, %{"profile_id" => socket.assigns.profile.id, "kind" => "other"})

    case Compliance.add_compliance_task(params, ash_opts(socket)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added to the calendar")
         |> push_patch(to: ~p"/compliance/filings")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end
end
