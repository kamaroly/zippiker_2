defmodule ZippikerWeb.EmployeeLive.Index do
  @moduledoc "The people directory: search, department and status filters, headline numbers."
  use ZippikerWeb, :live_view

  alias Zippiker.HR

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    {:ok,
     socket
     |> assign(:page_title, "Employees")
     |> assign(:summary, HR.hr_summary!(opts))
     |> assign(:departments, HR.list_departments!(opts))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    department = Enum.find(socket.assigns.departments, &(&1.id == params["department"]))
    status = if params["status"] == "terminated", do: :terminated, else: :active

    page =
      HR.list_employees!(
        %{query: query, status: status, department_id: department && department.id},
        ash_opts(socket) ++
          [page: [limit: 50, offset: (page_param(params) - 1) * 50, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, department: department, status: status, page: page)
     |> stream(:employees, page.results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: employees_path(socket.assigns, %{q: query}))}
  end

  def handle_event("department", %{"department" => id}, socket) do
    {:noreply, push_patch(socket, to: employees_path(socket.assigns, %{department: id}))}
  end

  defp employees_path(assigns, overrides) do
    query_path(
      ~p"/hr/employees",
      Map.merge(
        %{
          q: assigns.query,
          department: assigns.department && assigns.department.id,
          status: if(assigns.status == :terminated, do: "terminated")
        },
        overrides
      )
    )
  end
end
