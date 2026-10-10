defmodule ZippikerWeb.BomLive.Form do
  @moduledoc """
  New or edit a bill of materials: the product, how many it makes, the
  components (stock-tracked products and quantities) and the operations
  (minutes at a work center). Rows live in the socket until saved.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Catalog, Manufacturing}

  @impl true
  def mount(params, _session, socket) do
    opts = ash_opts(socket)

    socket =
      assign(socket,
        products: Catalog.list_products!(%{tracked_only?: true, active_only?: true}, opts),
        work_centers: Manufacturing.list_work_centers!(%{active_only?: true}, opts),
        errors: []
      )

    {:ok, load(socket, socket.assigns.live_action, params)}
  end

  defp load(socket, :new, _params) do
    assign(socket,
      bom: nil,
      page_title: "New bill of materials",
      fields: %{
        "product_id" => "",
        "reference" => "Standard",
        "quantity" => "1",
        "notes" => "",
        "active?" => "true"
      },
      components: [component_row(%{})],
      operations: []
    )
  end

  defp load(socket, :edit, %{"id" => id}) do
    bom =
      Manufacturing.get_bom!(id, ash_opts(socket) ++ [load: [:product, :components, :operations]])

    assign(socket,
      bom: bom,
      page_title: "Edit #{bom.product.name} · #{bom.reference}",
      fields: %{
        "product_id" => bom.product_id,
        "reference" => bom.reference,
        "quantity" => qty(bom.quantity),
        "notes" => bom.notes || "",
        "active?" => to_string(bom.active?)
      },
      components: Enum.map(bom.components, &component_row/1),
      operations: Enum.map(bom.operations, &operation_row/1)
    )
  end

  defp component_row(component) do
    %{
      "key" => Map.get(component, :id) || Ash.UUID.generate(),
      "id" => Map.get(component, :id),
      "product_id" => Map.get(component, :product_id) || "",
      "quantity" => if(q = Map.get(component, :quantity), do: qty(q), else: "1")
    }
  end

  defp operation_row(operation) do
    %{
      "key" => Map.get(operation, :id) || Ash.UUID.generate(),
      "id" => Map.get(operation, :id),
      "name" => Map.get(operation, :name) || "",
      "work_center_id" => Map.get(operation, :work_center_id) || "",
      "minutes" => if(m = Map.get(operation, :minutes), do: qty(m), else: "30"),
      "instructions" => Map.get(operation, :instructions) || ""
    }
  end

  @impl true
  def handle_event("change", params, socket),
    do: {:noreply, socket |> assign_params(params) |> assign(:errors, [])}

  def handle_event("add_component", _params, socket),
    do: {:noreply, update(socket, :components, &(&1 ++ [component_row(%{})]))}

  def handle_event("add_operation", _params, socket) do
    row = operation_row(%{work_center_id: List.first(socket.assigns.work_centers, %{id: ""}).id})
    {:noreply, update(socket, :operations, &(&1 ++ [row]))}
  end

  def handle_event("remove", %{"list" => list, "key" => key}, socket)
      when list in ["components", "operations"] do
    list = String.to_existing_atom(list)
    {:noreply, update(socket, list, fn rows -> Enum.reject(rows, &(&1["key"] == key)) end)}
  end

  def handle_event("save", params, socket) do
    socket = assign_params(socket, params)
    fields = socket.assigns.fields

    attrs = %{
      reference: fields["reference"],
      quantity: fields["quantity"],
      notes: fields["notes"],
      active?: fields["active?"] == "true",
      components:
        socket.assigns.components
        |> Enum.reject(&(&1["product_id"] in ["", nil]))
        |> Enum.with_index()
        |> Enum.map(fn {row, index} ->
          row |> Map.take(~w(id product_id quantity)) |> Map.put("position", index) |> compact()
        end),
      operations:
        socket.assigns.operations
        |> Enum.reject(&(String.trim(&1["name"]) == ""))
        |> Enum.with_index()
        |> Enum.map(fn {row, index} ->
          row
          |> Map.take(~w(id name work_center_id minutes instructions))
          |> Map.put("position", index)
          |> compact()
        end)
    }

    result =
      case socket.assigns.bom do
        nil ->
          Manufacturing.create_bom(
            Map.put(attrs, :product_id, fields["product_id"]),
            ash_opts(socket)
          )

        bom ->
          Manufacturing.update_bom(bom, attrs, ash_opts(socket))
      end

    case result do
      {:ok, _bom} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bill of materials saved")
         |> push_navigate(to: ~p"/manufacturing/boms")}

      {:error, error} ->
        {:noreply, assign(socket, :errors, [error_message(error)])}
    end
  end

  defp compact(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp assign_params(socket, params) do
    assign(socket,
      fields: Map.merge(socket.assigns.fields, Map.get(params, "bom", %{})),
      components:
        merge_rows(socket.assigns.components, params["components"], ~w(product_id quantity)),
      operations:
        merge_rows(
          socket.assigns.operations,
          params["operations"],
          ~w(name work_center_id minutes instructions)
        )
    )
  end

  defp merge_rows(rows, nil, _fields), do: rows

  defp merge_rows(rows, params, fields) do
    Enum.map(rows, fn row ->
      Map.merge(row, Map.take(Map.get(params, row["key"], %{}), fields))
    end)
  end
end
