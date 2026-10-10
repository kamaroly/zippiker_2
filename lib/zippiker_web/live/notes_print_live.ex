defmodule ZippikerWeb.NotesPrintLive do
  @moduledoc """
  Several delivery notes or goods received notes in one printout, one per
  page (`?ids=a,b,c`). Opened from the Print menu of an order, invoice or bill.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Purchasing, Sales}

  @delivery_loads [
    :sales_order,
    :invoice,
    :warehouse,
    :legal_entity,
    customer: [:addresses],
    lines: [:product]
  ]

  @receipt_loads [
    :purchase_order,
    :warehouse,
    :legal_entity,
    supplier: [:addresses],
    lines: [:product]
  ]

  @impl true
  def mount(params, _session, socket) do
    ids = params |> Map.get("ids", "") |> String.split(",", trim: true)
    opts = ash_opts(socket)

    notes =
      ids
      |> Enum.map(fn id ->
        case socket.assigns.live_action do
          :deliveries -> Sales.get_delivery(id, opts ++ [load: @delivery_loads])
          :goods_receipts -> Purchasing.get_goods_receipt(id, opts ++ [load: @receipt_loads])
        end
      end)
      |> Enum.flat_map(fn
        {:ok, note} -> [note]
        _ -> []
      end)

    {:ok,
     assign(socket,
       notes: notes,
       page_title:
         if(socket.assigns.live_action == :deliveries,
           do: "Delivery notes",
           else: "Goods received notes"
         )
     )}
  end
end
