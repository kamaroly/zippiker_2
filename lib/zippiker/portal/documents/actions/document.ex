defmodule Zippiker.Portal.Documents.Actions.Document do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Portal.Access
  alias Zippiker.{Purchasing, Sales}

  @types %{
    quote: {Sales.Quote, :customer, :customer_id},
    sales_order: {Sales.SalesOrder, :customer, :customer_id},
    invoice: {Sales.Invoice, :customer, :customer_id},
    rfq: {Purchasing.Rfq, :supplier, :supplier_id},
    purchase_order: {Purchasing.PurchaseOrder, :supplier, :supplier_id},
    bill: {Purchasing.Bill, :supplier, :supplier_id}
  }

  @impl true
  def run(input, _opts, context) do
    {resource, kind, field} = Map.fetch!(@types, input.arguments.type)

    with {:ok, document, _organization} <-
           fetch(
             context.actor,
             input.arguments.access_id,
             kind,
             resource,
             field,
             input.arguments.id
           ),
         do: {:ok, document}
  end

  @doc "A party's non-draft document, loaded for display, with the team: `{:ok, document, organization}`."
  def fetch(actor, access_id, kind, resource, field, id) do
    with {:ok, access, organization} <- Access.verify(actor, access_id, kind),
         opts = Access.opts(organization),
         {:ok, document} <- Ash.get(resource, id, opts),
         true <- Map.get(document, field) == access.party_id and document.status != :draft do
      loads =
        if kind == :customer,
          do: [:legal_entity, :lines, :contact, customer: [:addresses]],
          else: [:legal_entity, :lines, supplier: [:addresses]]

      {:ok, Ash.load!(document, loads, opts), organization}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, "document not found"}
    end
  end
end
