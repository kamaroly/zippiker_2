defmodule ZippikerWeb.BomLive.Index do
  @moduledoc "Bills of materials: each product's components, operations and estimated unit cost."
  use ZippikerWeb, :live_view

  alias Zippiker.Manufacturing
  alias Zippiker.Manufacturing.Costing

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    {:ok,
     assign(socket,
       page_title: "Bills of materials",
       boms: Manufacturing.list_boms!(opts),
       currency: Zippiker.Accounts.default_legal_entity!(opts).currency
     )}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    bom = Enum.find(socket.assigns.boms, &(&1.id == id))

    case Manufacturing.delete_bom(bom, ash_opts(socket)) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Bill of materials deleted")
         |> assign(:boms, Manufacturing.list_boms!(ash_opts(socket)))}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Production orders use this bill of materials; deactivate it instead"
         )}
    end
  end

  defp unit_cost(bom), do: Costing.estimate(bom, bom.quantity).unit_cost |> Decimal.round(2)
end
