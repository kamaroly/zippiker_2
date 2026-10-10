defmodule Zippiker.Sales.Invoice.Changes.ShipGoods do
  @moduledoc """
  Issuing an invoice ships its stock-tracked goods. Invoices for a sales
  order ship only what the order hasn't delivered yet, then mark the order
  delivered; a fully delivered order ships nothing.
  """
  use Ash.Resource.Change

  alias Zippiker.Sales.{SalesOrderLine, Shipping}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, invoice ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      loaded =
        Ash.load!(
          invoice,
          [:customer, lines: [:product], sales_order: [lines: [:product]]],
          opts
        )

      case loaded.sales_order do
        %{status: :delivered} ->
          {:ok, invoice}

        nil ->
          items = for line <- loaded.lines, do: {line, line.quantity}

          with {:ok, _delivery} <- Shipping.deliver(loaded, items, :invoice, opts),
               do: {:ok, invoice}

        order ->
          items = for line <- order.lines, do: {line, SalesOrderLine.remaining(line)}
          extra = %{warehouse_id: order.warehouse_id}

          with {:ok, _delivery} <- Shipping.deliver(loaded, items, :invoice, opts, extra),
               {:ok, _order} <-
                 order
                 |> Ash.Changeset.for_update(:mark_delivered, %{}, opts)
                 |> Ash.update(authorize?: false) do
            {:ok, invoice}
          end
      end
    end)
  end
end
