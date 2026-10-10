defmodule ZippikerWeb.InventoryLive.OperationPrint do
  @moduledoc "Print view of a goods received note, delivery note or adjustment slip."
  use ZippikerWeb, :live_view

  alias Zippiker.Inventory

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    operation =
      Inventory.get_stock_operation!(
        id,
        ash_opts(socket) ++
          [load: [:legal_entity, :warehouse, party: [:addresses], movements: [:product]]]
      )

    {:ok, assign(socket, operation: operation, page_title: operation.number)}
  end
end
