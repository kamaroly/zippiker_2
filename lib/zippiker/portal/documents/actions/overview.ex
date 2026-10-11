defmodule Zippiker.Portal.Documents.Actions.Overview do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.{Parties, Purchasing, Sales}
  alias Zippiker.Portal.Access

  @impl true
  def run(input, _opts, context) do
    with {:ok, access, organization} <- Access.verify(context.actor, input.arguments.access_id) do
      opts = Access.opts(organization)
      party = Parties.get_party!(access.party_id, opts)

      {:ok,
       Map.merge(
         %{access: access, organization: organization, party: party},
         documents(access, opts)
       )}
    end
  end

  defp documents(%{kind: :customer, party_id: id}, opts) do
    invoices = read(Sales.Invoice, id, :customer_id, opts, [:amount_due], &(&1.status != :draft))

    outstanding =
      invoices
      |> Enum.filter(&(&1.status == :issued))
      |> Enum.map(& &1.amount_due)
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(nil, fn amount, sum -> if sum, do: Money.add!(sum, amount), else: amount end)

    %{
      quotes: read(Sales.Quote, id, :customer_id, opts, [], &(&1.status != :draft)),
      orders: read(Sales.SalesOrder, id, :customer_id, opts, [], &(&1.status != :draft)),
      invoices: invoices,
      outstanding: outstanding
    }
  end

  defp documents(%{kind: :supplier, party_id: id}, opts) do
    %{
      rfqs: read(Purchasing.Rfq, id, :supplier_id, opts, [], &(&1.status != :draft)),
      purchase_orders:
        read(Purchasing.PurchaseOrder, id, :supplier_id, opts, [], &(&1.status != :draft)),
      bills: read(Purchasing.Bill, id, :supplier_id, opts, [:amount_due], &(&1.status != :draft))
    }
  end

  # Documents shown to outsiders: never drafts.
  defp read(resource, party_id, field, opts, loads, keep) do
    resource
    |> Ash.Query.filter(^Ash.Expr.ref(field) == ^party_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load(loads)
    |> Ash.read!(opts)
    |> Enum.filter(keep)
  end
end
