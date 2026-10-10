defmodule ZippikerWeb.ProductionLive.JobCard do
  @moduledoc "Printable job card for the shop floor: components to pick and operations to do."
  use ZippikerWeb, :live_view

  alias Zippiker.Manufacturing
  alias Zippiker.Manufacturing.Costing

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    order =
      Manufacturing.get_production_order!(
        id,
        ash_opts(socket) ++
          [
            load: [
              :product,
              :warehouse,
              :legal_entity,
              bom: [components: [product: [:on_hand]], operations: [:work_center]]
            ]
          ]
      )

    {:ok,
     assign(socket,
       order: order,
       page_title: "Job card #{order.number}",
       requirements: Costing.requirements(order.bom, order.quantity),
       operations: Costing.operations(order.bom, order.quantity)
     )}
  end
end
