defmodule ZippikerWeb.WorkflowLive.Groups do
  @moduledoc """
  Approval groups (Finance, Management…): a workflow step assigned to a
  group can be decided by any one of its members.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Workflow

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Approval groups", members: member_options(socket.assigns))
     |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params),
    do: assign(socket, group: nil, editing?: true, name: "", description: "", member_ids: [])

  defp apply_action(socket, :edit, %{"id" => id}) do
    group = Enum.find(socket.assigns.groups, &(&1.id == id))

    assign(socket,
      group: group,
      editing?: true,
      name: group.name,
      description: group.description || "",
      member_ids: Enum.map(group.members, & &1.id)
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, group: nil, editing?: false)

  @impl true
  def handle_event("save", %{"group" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      member_ids: params |> Map.get("member_ids", []) |> Enum.reject(&(&1 == ""))
    }

    result =
      case socket.assigns.group do
        nil -> Workflow.create_approval_group(attrs, ash_opts(socket))
        group -> Workflow.update_approval_group(group, attrs, ash_opts(socket))
      end

    case result do
      {:ok, _group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group saved")
         |> load()
         |> push_patch(to: ~p"/approvals/groups")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    group = Enum.find(socket.assigns.groups, &(&1.id == id))

    case Workflow.delete_approval_group(group, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Group deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket), do: assign(socket, :groups, Workflow.list_approval_groups!(ash_opts(socket)))
end
