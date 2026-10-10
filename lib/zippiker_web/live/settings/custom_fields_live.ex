defmodule ZippikerWeb.Settings.CustomFieldsLive do
  @moduledoc "Manage custom fields per record type (contacts, companies, leads, deals)."
  use ZippikerWeb, :live_view

  alias Zippiker.Extensibility
  alias Zippiker.Extensibility.{CustomFieldDefinition, Entity, FieldType}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Custom fields")
     |> assign(:entities, Enum.map(Entity.values(), &{Entity.label(&1), &1}))
     |> assign(:types, Enum.map(FieldType.values(), &{FieldType.label(&1), &1}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    entity = Enum.find(Entity.values(), :person, &(to_string(&1) == params["entity"]))

    socket =
      socket
      |> assign(:entity, entity)
      |> load_fields()

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      CustomFieldDefinition
      |> AshPhoenix.Form.for_create(:create,
        as: "field",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"entity" => socket.assigns.entity, "type" => "text"}
      )
      |> to_form()

    assign(socket, form: form, field: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    field = Extensibility.get_custom_field!(id, ash_opts(socket))

    form =
      field
      |> AshPhoenix.Form.for_update(:update,
        as: "field",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, field: field)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, field: nil)

  @impl true
  def handle_event("validate", %{"field" => params}, socket) do
    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, split_options(params)))}
  end

  def handle_event("save", %{"field" => params}, socket) do
    params =
      params
      |> split_options()
      |> then(
        &if(socket.assigns.field,
          do: &1,
          else: Map.put(&1, "position", length(socket.assigns.fields))
        )
      )

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _field} ->
        {:noreply,
         socket
         |> put_flash(:info, "Field saved")
         |> push_patch(to: ~p"/settings/custom-fields?entity=#{socket.assigns.entity}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    id |> Extensibility.get_custom_field!(opts) |> Extensibility.archive_custom_field!(opts)
    {:noreply, socket |> put_flash(:info, "Field archived") |> load_fields()}
  end

  def handle_event("move", %{"id" => id, "dir" => dir}, socket) do
    opts = ash_opts(socket)
    fields = socket.assigns.fields
    index = Enum.find_index(fields, &(&1.id == id))
    target = if dir == "up", do: index - 1, else: index + 1

    if index && target >= 0 && target < length(fields) do
      fields
      |> List.replace_at(index, Enum.at(fields, target))
      |> List.replace_at(target, Enum.at(fields, index))
      |> Enum.with_index()
      |> Enum.each(fn {field, position} ->
        if field.position != position,
          do: Extensibility.update_custom_field!(field, %{position: position}, opts)
      end)
    end

    {:noreply, load_fields(socket)}
  end

  defp load_fields(socket) do
    fields = Extensibility.list_custom_fields!(socket.assigns.entity, ash_opts(socket))

    socket
    |> assign(:fields, fields)
    |> stream(:fields, fields, reset: true)
  end

  defp split_options(%{"options" => options} = params) when is_binary(options),
    do: Map.put(params, "options", String.split(options, ["\r\n", "\n"]))

  defp split_options(params), do: params

  defp selected_type(form) do
    case AshPhoenix.Form.value(form.source, :type) do
      type when is_binary(type) -> String.to_existing_atom(type)
      type -> type
    end
  rescue
    ArgumentError -> nil
  end
end
