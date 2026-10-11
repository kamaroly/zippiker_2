defmodule Zippiker.Portal.Documents.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Portal.Documents.Actions

  actions do
    action :overview, :map do
      description "The party's documents and balance (customer or supplier view)."
      argument :access_id, :uuid, allow_nil?: false
      run Actions.Overview
    end

    action :document, :struct do
      description "One of the party's documents, with its lines."
      argument :access_id, :uuid, allow_nil?: false

      argument :type, :atom,
        allow_nil?: false,
        constraints: [one_of: [:quote, :sales_order, :invoice, :rfq, :purchase_order, :bill]]

      argument :id, :uuid, allow_nil?: false
      run Actions.Document
    end

    action :respond_to_quote, :struct do
      description "A customer accepts or declines a quote sent to them."
      argument :access_id, :uuid, allow_nil?: false
      argument :quote_id, :uuid, allow_nil?: false
      argument :decision, :atom, allow_nil?: false, constraints: [one_of: [:accept, :decline]]
      run Actions.RespondToQuote
    end

    action :submit_rfq_prices, :struct do
      description "A supplier answers a request for quotation with their unit prices."
      argument :access_id, :uuid, allow_nil?: false
      argument :rfq_id, :uuid, allow_nil?: false
      argument :prices, :map, allow_nil?: false, description: "`%{line_id => unit price}`"
      argument :reference, :string, constraints: [max_length: 60]
      run Actions.SubmitRfqPrices
    end

    action :acknowledge_purchase_order, :struct do
      description "A supplier confirms they received the purchase order."
      argument :access_id, :uuid, allow_nil?: false
      argument :purchase_order_id, :uuid, allow_nil?: false
      run Actions.AcknowledgePurchaseOrder
    end
  end
end
