defmodule ZippikerWeb.GoodsReceiptLive.Show do
  @moduledoc "A goods received note: what came, from whom, against which order; print it."
  use ZippikerWeb, :live_view

  alias Zippiker.Purchasing

  @loads [
    :purchase_order,
    :bill,
    :warehouse,
    :received_by,
    :stock_operation,
    :legal_entity,
    supplier: [:addresses],
    lines: [:product]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    note = Purchasing.get_goods_receipt!(id, ash_opts(socket) ++ [load: @loads])

    {:ok,
     assign(socket,
       note: note,
       page_title: note.number,
       print?: socket.assigns.live_action == :print
     )}
  end
end
