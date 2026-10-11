defmodule ZippikerWeb.Settings.RolesLive do
  @moduledoc """
  Roles and permissions: the built-in roles and custom ones, each a set of
  permissions (what members holding the role may do). Admins and people
  with "Create and edit roles" manage them.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Accounts
  alias Zippiker.Accounts.Permissions

  @impl true
  def mount(_params, _session, socket) do
    organization = socket.assigns.current_organization

    sections =
      for {key, label, module} <- Permissions.sections(),
          permissions = Enum.filter(Permissions.all(), &(&1.section == key)),
          permissions != [] do
        %{
          key: key,
          label: label,
          enabled?: is_nil(module) or ZippikerWeb.Modules.enabled?(organization, module),
          permissions: Enum.map(permissions, &Map.put(&1, :level, level(&1)))
        }
      end

    {:ok, socket |> assign(page_title: "Roles & permissions", sections: sections) |> load()}
  end

  # How the permission relates to the default rules, for the hint shown next to it.
  defp level(%{actions: []}), do: :view

  defp level(%{actions: actions}) do
    levels =
      for {resource, names} <- actions, name <- names, do: Permissions.level(resource, name)

    cond do
      :admin in levels -> :admin
      :open in levels -> :open
      true -> :member
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    if socket.assigns.live_action != :index and not can?(socket.assigns, "roles.manage") do
      {:noreply,
       socket
       |> put_flash(:error, "Your role doesn't allow editing roles.")
       |> push_patch(to: ~p"/settings/roles")}
    else
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, role: nil)

  defp apply_action(socket, :new, params) do
    copy = params["copy"] && Accounts.get_role!(params["copy"], ash_opts(socket))

    selected =
      if copy, do: copy.permissions, else: Permissions.views()

    form =
      Accounts.Role
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> AshPhoenix.Form.validate(%{
        "name" => if(copy, do: "#{copy.name} (copy)", else: ""),
        "description" => copy && copy.description,
        "permissions" => selected
      })
      |> to_form()

    assign(socket, form: form, role: nil, selected: MapSet.new(selected))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    role = Accounts.get_role!(id, ash_opts(socket))
    form = role |> AshPhoenix.Form.for_update(:update, form_opts(socket)) |> to_form()
    assign(socket, form: form, role: role, selected: MapSet.new(role.permissions))
  end

  defp form_opts(socket),
    do: [
      as: "role",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]

  @impl true
  def handle_event("validate", %{"role" => params}, socket) do
    selected = selected_from(params)
    params = Map.put(params, "permissions", MapSet.to_list(selected))

    {:noreply,
     assign(socket,
       form: AshPhoenix.Form.validate(socket.assigns.form, params),
       selected: selected
     )}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    keys =
      socket.assigns.sections
      |> Enum.find(&(to_string(&1.key) == section))
      |> Map.fetch!(:permissions)
      |> Enum.map(& &1.key)

    selected = socket.assigns.selected

    selected =
      if Enum.all?(keys, &MapSet.member?(selected, &1)),
        do: MapSet.difference(selected, MapSet.new(keys)),
        else: MapSet.union(selected, MapSet.new(keys))

    form =
      AshPhoenix.Form.validate(
        socket.assigns.form,
        Map.put(socket.assigns.form.params || %{}, "permissions", MapSet.to_list(selected))
      )

    {:noreply, assign(socket, form: form, selected: selected)}
  end

  def handle_event("save", %{"role" => params}, socket) do
    params = Map.put(params, "permissions", MapSet.to_list(selected_from(params)))

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{role.name} saved")
         |> load()
         |> push_patch(to: ~p"/settings/roles")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("reset", %{"id" => id}, socket) do
    role = Accounts.get_role!(id, ash_opts(socket))

    case Accounts.reset_role(role, ash_opts(socket)) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{role.name} is back to its default permissions")
         |> load()
         |> push_patch(to: ~p"/settings/roles")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    role = Accounts.get_role!(id, ash_opts(socket))

    case Accounts.delete_role(role, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "#{role.name} deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  # Checkboxes post `permissions[]` (plus an empty marker so "none" clears it).
  defp selected_from(params) do
    params
    |> Map.get("permissions", [])
    |> List.wrap()
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new()
  end

  defp load(socket) do
    roles = Accounts.list_roles!(ash_opts(socket))
    assign(socket, roles: roles)
  end

  defp section_state(section, selected) do
    count = Enum.count(section.permissions, &MapSet.member?(selected, &1.key))

    cond do
      count == 0 -> :none
      count == length(section.permissions) -> :all
      true -> :some
    end
  end

  defp dom_key(key), do: "permission-" <> String.replace(key, ".", "-")

  defp summary(role) do
    keys = MapSet.new(role.permissions)
    total = length(Permissions.keys())
    "#{MapSet.size(keys)} of #{total} permissions"
  end
end
