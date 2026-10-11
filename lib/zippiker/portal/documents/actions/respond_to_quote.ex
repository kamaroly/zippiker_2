defmodule Zippiker.Portal.Documents.Actions.RespondToQuote do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Portal.Access
  alias Zippiker.Portal.Documents.Actions.Document

  @impl true
  def run(input, _opts, context) do
    args = input.arguments

    with {:ok, quote, organization} <-
           Document.fetch(
             context.actor,
             args.access_id,
             :customer,
             Zippiker.Sales.Quote,
             :customer_id,
             args.quote_id
           ),
         :ok <-
           if(quote.status == :sent,
             do: :ok,
             else: {:error, "this quote can no longer be answered"}
           ) do
      quote
      |> Ash.Changeset.for_update(args.decision, %{}, Access.opts(organization))
      |> Ash.update()
    end
  end
end
