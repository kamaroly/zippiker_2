defmodule Zippiker.Portal.Documents.Actions.AcknowledgePurchaseOrder do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Portal.Access
  alias Zippiker.Portal.Documents.Actions.Document

  @impl true
  def run(input, _opts, context) do
    args = input.arguments

    with {:ok, order, organization} <-
           Document.fetch(
             context.actor,
             args.access_id,
             :supplier,
             Zippiker.Purchasing.PurchaseOrder,
             :supplier_id,
             args.purchase_order_id
           ) do
      order
      |> Ash.Changeset.for_update(:acknowledge, %{}, Access.opts(organization))
      |> Ash.update()
    end
  end
end
