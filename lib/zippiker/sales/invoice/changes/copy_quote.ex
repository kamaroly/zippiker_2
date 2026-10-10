defmodule Zippiker.Sales.Invoice.Changes.CopyQuote do
  @moduledoc "Fills a new invoice from a quote: parties, deal, legal entity, notes and lines."
  use Ash.Resource.Change

  @line_fields [
    :position,
    :description,
    :quantity,
    :unit,
    :unit_price,
    :discount_percent,
    :tax_rate_id,
    :product_id
  ]

  @impl true
  def change(changeset, _opts, _context) do
    quote_id = Ash.Changeset.get_argument(changeset, :quote_id)
    opts = [tenant: changeset.tenant, authorize?: false]

    case Zippiker.Sales.get_quote(quote_id, opts ++ [load: [:lines, :invoice]]) do
      {:ok, %{invoice: %{}}} ->
        Ash.Changeset.add_error(changeset,
          field: :quote_id,
          message: "this quote was already invoiced"
        )

      {:ok, %{status: :declined}} ->
        Ash.Changeset.add_error(changeset,
          field: :quote_id,
          message: "declined quotes can't be invoiced"
        )

      {:ok, quote} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          quote_id: quote.id,
          customer_id: quote.customer_id,
          contact_id: quote.contact_id,
          deal_id: quote.deal_id,
          owner_id: quote.owner_id,
          legal_entity_id: quote.legal_entity_id,
          notes: quote.notes
        })
        |> Ash.Changeset.set_argument(:lines, Enum.map(quote.lines, &Map.take(&1, @line_fields)))

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :quote_id, message: "quote not found")
    end
  end
end
